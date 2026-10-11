import Foundation

// DevicesModel.swift
// Shows battery levels of Bluetooth gadgets that are connected right now (AirPods, mouse, keyboard...).
// It asks macOS's built-in, read-only "system_profiler" report for the Bluetooth list. No permission is
// needed and nothing leaves your Mac. It only runs when you open this tab or press Refresh.
// (Not included: "which apps use your mic" and "Ring my iPhone" - macOS gives apps no public way to do those.)

struct BluetoothGadget: Identifiable, Equatable {
    let id: String
    let name: String
    let kind: String
    /// e.g. ("Left", 80), ("Case", 55)
    let batteries: [(label: String, percent: Int)]

    static func == (a: BluetoothGadget, b: BluetoothGadget) -> Bool { a.id == b.id && a.name == b.name && a.batteries.map { $0.percent } == b.batteries.map { $0.percent } }
}

final class DevicesModel: ObservableObject {
    @Published private(set) var gadgets: [BluetoothGadget] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var updated: Date?

    @MainActor
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        let data = await Task.detached(priority: .utility) { Self.runReport() }.value
        guard let data = data else { error = "Couldn't read the Bluetooth list."; return }
        gadgets = Self.parse(data)
        updated = Date()
    }

    private static func runReport() -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return data
    }

    /// Pure parsing (easy to test).
    static func parse(_ data: Data) -> [BluetoothGadget] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let reports = root["SPBluetoothDataType"] as? [[String: Any]] else { return [] }
        var result: [BluetoothGadget] = []
        for report in reports {
            let connected = report["device_connected"] as? [[String: Any]] ?? []
            for entry in connected {
                for (name, value) in entry {
                    guard let info = value as? [String: Any] else { continue }
                    var batteries: [(String, Int)] = []
                    let keys: [(String, String)] = [("device_batteryLevelMain", "Battery"), ("device_batteryLevelLeft", "Left"),
                                                    ("device_batteryLevelRight", "Right"), ("device_batteryLevelCase", "Case")]
                    for (key, label) in keys {
                        if let text = info[key] as? String, let n = Int(text.trimmingCharacters(in: CharacterSet(charactersIn: "% "))) {
                            batteries.append((label, n))
                        }
                    }
                    let kind = (info["device_minorType"] as? String) ?? "Bluetooth device"
                    result.append(BluetoothGadget(id: (info["device_address"] as? String) ?? name, name: name, kind: kind, batteries: batteries))
                }
            }
        }
        return result.sorted { $0.name < $1.name }
    }
}
