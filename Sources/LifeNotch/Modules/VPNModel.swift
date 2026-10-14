import Foundation
import AppKit

// VPNModel.swift
// Controls the VPN connections that are ALREADY set up on your Mac (System Settings > VPN, or created by a VPN
// app such as Proton VPN, Windscribe or Cloudflare WARP). It uses macOS's own `scutil --nc` tool: list, status,
// start, stop. LifeNotch does not carry your traffic, never creates or edits VPN settings, and every Connect /
// Disconnect asks you first. (A VPN engine built into LifeNotch would need a paid Apple developer account.)

struct VPNConnection: Identifiable, Equatable {
    let id: String          // the connection's UUID
    let name: String
    let status: String      // "Connected", "Disconnected", "Connecting", ...
    var isConnected: Bool { status.lowercased() == "connected" }
    var isBusy: Bool { ["connecting", "disconnecting"].contains(status.lowercased()) }
}

struct FreeVPNProvider: Identifiable {
    let name: String
    let note: String
    let url: String
    var id: String { name }
}

final class VPNModel: ObservableObject {
    @Published private(set) var connections: [VPNConnection] = []
    @Published private(set) var isWorking = false
    @Published var message = ""

    /// Official sites of VPNs that have a free tier. Free limits change, so check each site. Install the app,
    /// sign in there, and its connection will show up in this tab.
    static let providers: [FreeVPNProvider] = [
        FreeVPNProvider(name: "Proton VPN", note: "Free tier, no ads, run by the Proton Mail team", url: "https://protonvpn.com/free-vpn"),
        FreeVPNProvider(name: "Cloudflare WARP", note: "Free, simple, from Cloudflare (1.1.1.1 app)", url: "https://one.one.one.one"),
        FreeVPNProvider(name: "Windscribe", note: "Free tier with a monthly data allowance", url: "https://windscribe.com"),
        FreeVPNProvider(name: "Hide.me", note: "Free plan with a data limit", url: "https://hide.me/en/free-vpn"),
        FreeVPNProvider(name: "TunnelBear", note: "Small free data allowance", url: "https://www.tunnelbear.com")
    ]

    // MARK: Parsing (pure, easy to test)

    /// Lines look like:  * (Connected)   3F2A…-UUID VPN (com.example) "My VPN"   [VPN:com.example]
    static func parse(_ output: String) -> [VPNConnection] {
        output.split(whereSeparator: \.isNewline).compactMap { rawLine in
            let line = String(rawLine)
            guard let open = line.firstIndex(of: "("), let close = line[open...].firstIndex(of: ")") else { return nil }
            let status = String(line[line.index(after: open)..<close])
            let rest = line[line.index(after: close)...]
            guard let uuid = rest.split(separator: " ").first(where: { UUID(uuidString: String($0)) != nil }) else { return nil }
            guard let firstQuote = rest.firstIndex(of: "\""),
                  let lastQuote = rest.lastIndex(of: "\""), firstQuote < lastQuote else { return nil }
            let name = String(rest[rest.index(after: firstQuote)..<lastQuote])
            return VPNConnection(id: String(uuid), name: name, status: status)
        }
    }

    // MARK: Actions

    @MainActor
    func refresh() async {
        let output = await Task.detached(priority: .utility) { Self.run(["--nc", "list"]) }.value
        connections = Self.parse(output ?? "")
    }

    @MainActor
    func toggle(_ connection: VPNConnection) async {
        guard !isWorking else { return }
        let connecting = !connection.isConnected
        guard ModalHelper.confirm(title: connecting ? "Connect to \"\(connection.name)\"?" : "Disconnect \"\(connection.name)\"?",
                                  message: connecting ? "Your internet traffic will go through this VPN until you disconnect."
                                                      : "Your internet traffic will stop going through this VPN.",
                                  confirmTitle: connecting ? "Connect" : "Disconnect") else { return }
        isWorking = true
        message = ""
        defer { isWorking = false }
        _ = await Task.detached { Self.run(["--nc", connecting ? "start" : "stop", connection.name]) }.value
        // Give macOS a moment, then look again.
        for _ in 0..<5 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await refresh()
            if let updated = connections.first(where: { $0.id == connection.id }), !updated.isBusy { break }
        }
        if let updated = connections.first(where: { $0.id == connection.id }), updated.isConnected != connecting {
            message = connecting ? "It didn't connect. Open System Settings > VPN to check the details or sign in to the VPN app."
                                 : "It's still connected."
        }
    }

    func openSystemSettings() {
        for address in ["x-apple.systempreferences:com.apple.Network-Settings.extension",
                        "x-apple.systempreferences:com.apple.preference.network"] {
            if let url = URL(string: address), NSWorkspace.shared.open(url) { return }
        }
    }

    private static func run(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
