import SwiftUI
import AppKit

// VPNView.swift
// Connect or disconnect the VPNs already set up on this Mac, and find free VPN apps.

struct VPNView: View {
    @EnvironmentObject private var model: VPNModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    SectionTitle("Your VPNs")
                    Spacer()
                    Button("VPN settings") { model.openSystemSettings() }.buttonStyle(LNButtonStyle())
                }
                if model.connections.isEmpty {
                    Text("No VPN is set up on this Mac yet. Install one from the list on the right (or add one in System Settings > VPN), then come back.")
                        .lnFont(11).foregroundStyle(.secondary)
                }
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(model.connections) { connection in
                            HStack {
                                Image(systemName: connection.isConnected ? "lock.shield.fill" : "lock.open")
                                    .foregroundStyle(connection.isConnected ? Color.green : Color.secondary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(connection.name).lnFont(12.5, .semibold).lineLimit(1)
                                    Text(connection.status).lnFont(10).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(connection.isConnected ? "Disconnect" : "Connect") {
                                    Task { await model.toggle(connection) }
                                }
                                .buttonStyle(LNButtonStyle(prominent: !connection.isConnected))
                                .disabled(model.isWorking || connection.isBusy)
                            }
                            .card(padding: 8)
                        }
                    }
                }
                if !model.message.isEmpty { Text(model.message).lnFont(10.5).foregroundStyle(.orange) }
                Text("LifeNotch only switches VPNs that already exist on your Mac, and asks first. It never carries your traffic itself.")
                    .lnFont(9.5).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 6) {
                SectionTitle("Free VPN apps (official sites)")
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(VPNModel.providers) { provider in
                            Button {
                                if let url = URL(string: provider.url) { NSWorkspace.shared.open(url) }
                            } label: {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(provider.name).lnFont(12, .semibold)
                                    Text(provider.note).lnFont(10).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .card(padding: 8)
                        }
                    }
                }
                Text("Free tiers change and any VPN can see your traffic, so pick one you trust. Avoid random \"free server lists\".")
                    .lnFont(9.5).foregroundStyle(.secondary)
            }
            .frame(width: 270, alignment: .topLeading)
        }
        .task {
            while !Task.isCancelled {
                await model.refresh()
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
    }
}
