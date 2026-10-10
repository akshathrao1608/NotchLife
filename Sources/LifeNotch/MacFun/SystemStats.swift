import Foundation
import Network
import IOKit.ps

// SystemStats.swift
// Battery, Wi-Fi, storage, CPU and memory, using Apple's public system APIs only.
// Reading these needs no permission. For Wi-Fi we only say "connected or not": the Wi-Fi
// NAME would require the Location permission, which LifeNotch does not ask for.

final class SystemStatsModel: ObservableObject {
    @Published var batteryPercent: Int?
    @Published var isCharging = false
    @Published var onACPower = false
    @Published var wifiConnected = false
    @Published var networkDescription = "Checking…"
    @Published var storageFreeGB: Double = 0
    @Published var storageTotalGB: Double = 0
    @Published var cpuUsage: Double = 0          // 0...1
    @Published var memoryUsedGB: Double = 0
    @Published var memoryTotalGB: Double = 0
    /// Minutes until fully charged / until the battery runs out. nil = unknown.
    @Published var minutesToFull: Int?
    @Published var minutesToEmpty: Int?
    /// Network speed in bytes per second (all Wi-Fi/Ethernet "en" interfaces).
    @Published var downBytesPerSecond: Double = 0
    @Published var upBytesPerSecond: Double = 0

    private let monitor = NWPathMonitor()
    private var lightTimer: Timer?
    private var fullTimer: Timer?
    private var previousTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?
    private var previousNet: (rx: UInt64, tx: UInt64, time: Date)?

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let onWifi = path.status == .satisfied && path.usesInterfaceType(.wifi)
                self.wifiConnected = onWifi
                if path.status != .satisfied {
                    self.networkDescription = "Offline"
                } else if onWifi {
                    self.networkDescription = "Wi-Fi connected"
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.networkDescription = "Ethernet connected"
                } else {
                    self.networkDescription = "Online (not Wi-Fi)"
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "lifenotch.network"))
        readBattery()
    }

    // MARK: Light refresh (compact bar: battery + Wi-Fi)

    func startLightRefresh() {
        guard lightTimer == nil else { return }
        readBattery()
        lightTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.readBattery() }
    }

    func stopLightRefresh() {
        lightTimer?.invalidate()
        lightTimer = nil
    }

    // MARK: Full refresh (only while the System section is on screen)

    func startFullRefresh() {
        refreshAll()
        fullTimer?.invalidate()
        fullTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refreshAll() }
    }

    func stopFullRefresh() {
        fullTimer?.invalidate()
        fullTimer = nil
        previousTicks = nil
        previousNet = nil
    }

    private func refreshAll() {
        readBattery()
        readStorage()
        readCPU()
        readMemory()
        readNetwork()
    }

    // MARK: Readers

    private func readBattery() {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source).takeUnretainedValue() as? [String: Any],
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }
            batteryPercent = current * 100 / maximum
            isCharging = (description[kIOPSIsChargingKey] as? Bool) ?? false
            onACPower = (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            let full = description[kIOPSTimeToFullChargeKey] as? Int
            let empty = description[kIOPSTimeToEmptyKey] as? Int
            minutesToFull = (full ?? -1) > 0 ? full : nil
            minutesToEmpty = (empty ?? -1) > 0 ? empty : nil
            return
        }
        batteryPercent = nil   // a desktop Mac has no battery
    }

    private func readStorage() {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]) else { return }
        let gb = 1_000_000_000.0
        storageFreeGB = Double(values.volumeAvailableCapacityForImportantUsage ?? 0) / gb
        storageTotalGB = Double(values.volumeTotalCapacity ?? 0) / gb
    }

    private func cpuTicks() -> (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)? {
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        var info = host_cpu_load_info_data_t()
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return (info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3)
    }

    private func readCPU() {
        guard let now = cpuTicks() else { return }
        defer { previousTicks = now }
        guard let before = previousTicks else { return }
        let user = Double(now.user &- before.user)
        let system = Double(now.system &- before.system)
        let idle = Double(now.idle &- before.idle)
        let nice = Double(now.nice &- before.nice)
        let total = user + system + idle + nice
        cpuUsage = total > 0 ? (user + system + nice) / total : 0
    }

    /// "Full in 45 min", "1 h 5 min left", "Fully charged"... in plain words.
    var batteryWords: String {
        guard let percent = batteryPercent else { return "No battery" }
        func words(_ minutes: Int) -> String {
            minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
        }
        if isCharging, let m = minutesToFull { return "Full in " + words(m) }
        if isCharging { return "Charging, working out the time…" }
        if onACPower { return percent >= 100 ? "Fully charged" : "Plugged in" }
        if let m = minutesToEmpty { return words(m) + " left" }
        return "On battery"
    }

    private func networkBytes() -> (rx: UInt64, tx: UInt64) {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return (0, 0) }
        defer { freeifaddrs(pointer) }
        var rx: UInt64 = 0
        var tx: UInt64 = 0
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let interface = cursor {
            let name = String(cString: interface.pointee.ifa_name)
            if let address = interface.pointee.ifa_addr,
               address.pointee.sa_family == UInt8(AF_LINK),
               name.hasPrefix("en"),
               let data = interface.pointee.ifa_data {
                let stats = data.assumingMemoryBound(to: if_data.self).pointee
                rx += UInt64(stats.ifi_ibytes)
                tx += UInt64(stats.ifi_obytes)
            }
            cursor = interface.pointee.ifa_next
        }
        return (rx, tx)
    }

    private func readNetwork() {
        let now = networkBytes()
        let time = Date()
        defer { previousNet = (now.rx, now.tx, time) }
        guard let before = previousNet else { return }
        let seconds = time.timeIntervalSince(before.time)
        guard seconds > 0, now.rx >= before.rx, now.tx >= before.tx else { return }
        downBytesPerSecond = Double(now.rx - before.rx) / seconds
        upBytesPerSecond = Double(now.tx - before.tx) / seconds
    }

    static func speedText(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_000_000 { return String(format: "%.1f MB/s", bytesPerSecond / 1_000_000) }
        if bytesPerSecond >= 1_000 { return String(format: "%.0f KB/s", bytesPerSecond / 1_000) }
        return String(format: "%.0f B/s", bytesPerSecond)
    }

    private func readMemory() {
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        var stats = vm_statistics64_data_t()
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }
        let page = Double(sysconf(_SC_PAGESIZE))
        let used = (Double(stats.active_count) + Double(stats.wire_count) + Double(stats.compressor_page_count)) * page
        let gb = 1_073_741_824.0
        memoryUsedGB = used / gb
        memoryTotalGB = Double(ProcessInfo.processInfo.physicalMemory) / gb
    }
}
