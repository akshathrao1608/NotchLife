import SwiftUI

// NowPlayingView.swift
// What's playing in Music or Spotify, with previous / play-pause / next.

struct NowPlayingView: View {
    @EnvironmentObject private var model: NowPlayingModel
    @EnvironmentObject private var settings: AppSettings
    @State private var allowed = false

    var body: some View {
        Group {
            if !allowed {
                VStack(spacing: 10) {
                    EmptyStateView(icon: "music.note", title: "Now Playing is off",
                                   message: "LifeNotch can ask Music and Spotify what is playing. It only talks to them while this tab is open, and never opens them itself.")
                    Button("Allow…") {
                        allowed = ConsentGate.request(
                            .controlMusicApps, settings: settings,
                            explanation: "LifeNotch will ask Apple Music or Spotify (only if already running) for the song title, artist and position, and send play, pause and skip when you press the buttons. macOS will also show its own permission question.")
                        if allowed { model.start() }
                    }
                    .buttonStyle(LNButtonStyle(prominent: true))
                }
            } else if let track = model.track {
                HStack(spacing: 16) {
                    artwork(track)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(track.title).lnFont(18, .bold).lineLimit(2)
                        Text(track.artist).lnFont(13).foregroundStyle(.secondary)
                        Text(track.album).lnFont(11).foregroundStyle(.secondary)
                        ProgressView(value: min(track.position, max(track.duration, 1)), total: max(track.duration, 1))
                        HStack {
                            Text(NowPlayingModel.timeText(track.position)).lnFont(10).monospacedDigit()
                            Spacer()
                            Text(NowPlayingModel.timeText(track.duration)).lnFont(10).monospacedDigit()
                        }
                        .foregroundStyle(.secondary)
                        HStack(spacing: 14) {
                            LNIconButton(systemName: "backward.fill", label: "Previous track") { model.command("previous track") }
                            LNIconButton(systemName: track.isPlaying ? "pause.fill" : "play.fill",
                                         label: track.isPlaying ? "Pause" : "Play", isActive: true) { model.command("playpause") }
                            LNIconButton(systemName: "forward.fill", label: "Next track") { model.command("next track") }
                            Text("from \(track.source.rawValue)").lnFont(10).foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                EmptyStateView(icon: "music.note", title: "Nothing playing",
                               message: model.message.isEmpty ? "Play something in Music or Spotify." : model.message)
            }
        }
        .onAppear {
            allowed = settings.hasConsent(.controlMusicApps)
            if allowed { model.start() }
        }
        .onDisappear { model.stop() }
    }

    @ViewBuilder
    private func artwork(_ track: NowPlayingModel.Track) -> some View {
        Group {
            if let url = track.artworkURL {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { placeholder }
            } else {
                placeholder
            }
        }
        .frame(width: 130, height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(0.1))
            Image(systemName: "music.note").font(.system(size: 40)).foregroundStyle(.secondary)
        }
    }
}
