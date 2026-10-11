import SwiftUI

// DevicesView.swift
// Battery levels of connected AirPods and other Bluetooth accessories.

struct DevicesView: View {
    @EnvironmentObject private var model: DevicesModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.updated.map { "Updated " + $0.formatted(date: .omitted, time: .shortened) } ?? "").lnFont(10.5).foregroundStyle(.secondary)
                Spacer()
                Button { Task { await model.refresh() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    .buttonStyle(LNButtonStyle()).disabled(model.isLoading)
            }
            if let error = model.error { Text(error).lnFont(11).foregroundStyle(.orange) }
            if model.gadgets.isEmpty && !model.isLoading {
                EmptyStateView(icon: "headphones", title: "No Bluetooth devices connected",
                               message: "Connect AirPods or another accessory, then press Refresh.")
            }
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(model.gadgets) { gadget in
                        HStack {
                            Image(systemName: icon(for: gadget.kind)).frame(width: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(gadget.name).lnFont(13, .semibold)
                                Text(gadget.kind).lnFont(10).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if gadget.batteries.isEmpty {
                                Text("No battery info").lnFont(10.5).foregroundStyle(.secondary)
                            }
                            ForEach(Array(gadget.batteries.enumerated()), id: \.offset) { _, b in
                                VStack(spacing: 1) {
                                    Text("\(b.percent)%").lnFont(12, .bold).foregroundStyle(b.percent <= 20 ? Color.red : Color.primary)
                                    Text(b.label).lnFont(9).foregroundStyle(.secondary)
                                }
                                .frame(minWidth: 40)
                            }
                        }
                        .card(padding: 8)
                    }
                }
            }
            Text("Read from macOS's own Bluetooth report on this Mac. Nothing is sent anywhere.").lnFont(9.5).foregroundStyle(.secondary)
        }
        .task { await model.refresh() }
    }

    private func icon(for kind: String) -> String {
        let k = kind.lowercased()
        if k.contains("headphone") || k.contains("headset") { return "headphones" }
        if k.contains("keyboard") { return "keyboard" }
        if k.contains("mouse") || k.contains("trackpad") { return "magicmouse" }
        return "dot.radiowaves.left.and.right"
    }
}
