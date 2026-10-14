import SwiftUI

// ChatView.swift
// Chat on the same Wi-Fi with a shared room code. No accounts, no servers, nothing saved.

struct ChatView: View {
    @EnvironmentObject private var chat: LANChatModel
    @EnvironmentObject private var settings: AppSettings
    @State private var room = ""
    @State private var draft = ""

    var body: some View {
        if !chat.isOn {
            VStack(spacing: 10) {
                EmptyStateView(icon: "bubble.left.and.bubble.right.fill", title: "Chat on this Wi-Fi",
                               message: "You and a friend type the same room code. Messages are encrypted with that code, go straight between your Macs (no server, no account) and are not saved.")
                HStack {
                    TextField("Your handle", text: $settings.prefs.chatHandle).textFieldStyle(.roundedBorder).frame(width: 140)
                    SecureField("Room code (4+ characters)", text: $room).textFieldStyle(.roundedBorder).frame(width: 190)
                    Button("Join") { join() }.buttonStyle(LNButtonStyle(prominent: true)).disabled(room.count < 4)
                }
                if !chat.status.isEmpty { Text(chat.status).lnFont(10.5).foregroundStyle(.orange) }
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 6) {
                HStack {
                    Label(chat.peerCount == 0 ? "Waiting for others…" : "\(chat.peerCount) connected", systemImage: "wifi")
                        .lnFont(11).foregroundStyle(chat.peerCount == 0 ? Color.orange : Color.green)
                    Spacer()
                    Button("Leave room") { chat.leave(); room = "" }.buttonStyle(LNButtonStyle())
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(chat.messages) { message in
                                VStack(alignment: message.isMine ? .trailing : .leading, spacing: 1) {
                                    Text(message.isMine ? "You" : message.handle).lnFont(9.5).foregroundStyle(.secondary)
                                    Text(message.text).lnFont(12)
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(Capsule().fill(message.isMine ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.12)))
                                }
                                .frame(maxWidth: .infinity, alignment: message.isMine ? .trailing : .leading)
                                .id(message.id)
                            }
                        }
                    }
                    .onChange(of: chat.messages.count) { _, _ in
                        if let last = chat.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                HStack {
                    TextField("Message", text: $draft).textFieldStyle(.roundedBorder).onSubmit(send)
                    Button("Send", action: send).buttonStyle(LNButtonStyle(prominent: true)).disabled(draft.isEmpty)
                }
            }
        }
    }

    private func join() {
        guard ConsentGate.request(.localChat, settings: settings,
                                  explanation: "LifeNotch will advertise itself on your local network and connect to other LifeNotch Macs that use the same room code. macOS will also ask about Local Network access. Messages are encrypted and never saved.") else { return }
        chat.join(room: room, handle: settings.prefs.chatHandle)
    }

    private func send() { chat.send(draft); draft = "" }
}
