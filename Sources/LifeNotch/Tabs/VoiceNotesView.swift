import SwiftUI
import AppKit

// VoiceNotesView.swift
// Press Record, talk, press Stop. You get text. The recording itself is deleted straight away.

struct VoiceNotesView: View {
    @EnvironmentObject private var model: VoiceNotesModel
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 10) {
                Button {
                    Task { model.isRecording ? await model.stop() : await model.start(settings: settings) }
                } label: {
                    Image(systemName: model.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 28, weight: .bold))
                        .frame(width: 76, height: 76)
                        .foregroundStyle(.white)
                        .background(Circle().fill(model.isRecording ? Color.red : Color.accentColor))
                }
                .buttonStyle(.plain)
                .disabled(model.isWorking)
                .accessibilityLabel(model.isRecording ? "Stop recording" : "Start recording")
                Text(model.isRecording ? Countdown.clock(model.elapsed) : (model.isWorking ? "Working…" : "Tap to record"))
                    .lnFont(11).monospacedDigit().foregroundStyle(.secondary)
                if !model.message.isEmpty { Text(model.message).lnFont(10).foregroundStyle(.orange) }
                Text("Turned into text on this Mac. The recording is deleted.").lnFont(9.5)
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .frame(width: 190)
            .card()

            if model.notes.isEmpty {
                EmptyStateView(icon: "waveform", title: "No voice notes yet", message: "Your notes will appear here.")
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(model.notes) { note in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.date.formatted(date: .abbreviated, time: .shortened)).lnFont(10).foregroundStyle(.secondary)
                                Text(note.text).lnFont(12).textSelection(.enabled)
                                if !note.summary.isEmpty {
                                    Text(note.summary).lnFont(11).padding(6)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.08)))
                                    AIBadge()
                                }
                                HStack {
                                    Button("Copy") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(note.text, forType: .string)
                                    }
                                    Button("Summarise with AI") { Task { await model.summarise(note, settings: settings) } }
                                        .disabled(model.isWorking)
                                    Spacer()
                                    Button("Delete", role: .destructive) { model.delete(note) }
                                }
                                .buttonStyle(LNButtonStyle(prominent: false))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card()
                        }
                    }
                }
            }
        }
    }
}
