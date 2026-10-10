import SwiftUI

// WindowsView.swift
// Snap the window you were just using to a part of the screen. Press a zone here, or turn on the
// Control + Option shortcuts. Needs the Accessibility permission (LifeNotch asks first).

struct WindowsView: View {
    @EnvironmentObject private var snapper: WindowSnapper
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Front window: \(snapper.targetName)").lnFont(11.5, .medium)
                Spacer()
                if !snapper.isTrusted {
                    Label("Accessibility permission needed", systemImage: "lock.fill").lnFont(10.5).foregroundStyle(.orange)
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                ForEach(SnapZone.allCases) { zone in
                    Button { snapper.snap(zone, settings: settings) } label: {
                        VStack(spacing: 4) {
                            ZoneIcon(zone: zone).frame(width: 56, height: 36)
                            Text(zone.title).lnFont(10).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Snap window: \(zone.title)")
                }
            }
            if !snapper.message.isEmpty { Text(snapper.message).lnFont(10.5).foregroundStyle(.secondary) }
            Toggle("Keyboard shortcuts: Control+Option with ← → ↑ ↓ (halves), Return (maximize), C (center), U I J K (corners), D F G (thirds)",
                   isOn: $settings.prefs.windowHotKeysEnabled)
                .lnFont(11)
            Spacer()
        }
    }
}

/// A tiny picture of a screen with the zone highlighted.
struct ZoneIcon: View {
    let zone: SnapZone
    @Environment(\.lnAccent) private var accent

    var body: some View {
        GeometryReader { proxy in
            let u = zone.unitRect
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4).stroke(Color.primary.opacity(0.4), lineWidth: 1)
                RoundedRectangle(cornerRadius: 3).fill(accent)
                    .frame(width: u.width * proxy.size.width - 2, height: u.height * proxy.size.height - 2)
                    .offset(x: u.minX * proxy.size.width + 1, y: u.minY * proxy.size.height + 1)
            }
        }
        .accessibilityHidden(true)
    }
}
