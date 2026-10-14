import SwiftUI

// AudioView.swift
// Volume, mute and output device for the whole Mac.

struct AudioView: View {
    @EnvironmentObject private var model: AudioModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle("Volume")
                if model.volumeAvailable {
                    HStack {
                        Image(systemName: model.muted ? "speaker.slash.fill" : "speaker.fill")
                        Slider(value: Binding(get: { model.volume }, set: { model.setVolume($0) }), in: 0...1)
                        Image(systemName: "speaker.wave.3.fill")
                    }
                    Text("\(Int(model.volume * 100))%").lnFont(12, .semibold).monospacedDigit()
                    Toggle("Mute", isOn: Binding(get: { model.muted }, set: { model.setMuted($0) }))
                } else {
                    Text("This output has no software volume (use its own buttons).").lnFont(11).foregroundStyle(.secondary)
                }
                Text("Per-app volume and equalizers aren't possible: macOS gives apps no public way to change another app's sound.")
                    .lnFont(9.5).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .card()

            VStack(alignment: .leading, spacing: 6) {
                SectionTitle("Play sound through")
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(model.outputs) { output in
                            Button { model.select(output) } label: {
                                HStack {
                                    Image(systemName: output.id == model.currentID ? "checkmark.circle.fill" : "circle")
                                    Text(output.name).lnFont(12).lineLimit(1)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .card()
        }
        .onAppear { model.refresh() }
    }
}
