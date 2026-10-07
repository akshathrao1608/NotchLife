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

    private let monitor = NWPathMonitor()
    private var lightTimer: Timer?
    private var fullTimer: Timer?
    private var previousTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?

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
    }

    private func refreshAll() {
        readBattery()
        readStorage()
        readCPU()
        readMemory()
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
