import SwiftUI

// MessagesView.swift
// The Messages tab. Read this first: LifeNotch does NOT read your Messages. It shows notices
// that you choose to feed it (from Shortcuts or a private link), and it can open the real
// Messages app for you.

struct MessagesView: View {
    @EnvironmentObject private var hub: MessageHub
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ScrollView {
            if hub.isEnabled { enabledView } else { disabledView }
        }
    }

    // MARK: Off

    private var disabledView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("The Messages hub is OFF", systemImage: "lock.fill").lnFont(14, .bold)
            Text("""
                 When on, it shows an unread count and (optionally) short previews of notices YOU send to it.

                 • LifeNotch never reads the Messages app or its database.
                 • It cannot see other apps' notifications. You connect sources yourself, using a Shortcut or a private link.
                 • Previews are off by default; Do Not Disturb hides them but keeps the count.
                 """)
                .lnFont(12)
            Button("Turn on the Messages hub…") {
                let ok = ModalHelper.confirm(
                    title: "Turn on the Messages hub?",
                    message: "LifeNotch will keep a small list of notices that you send to it from Shortcuts or private links, and show an unread count. It will NOT read your Messages or any other app. You can turn it off any time.",
                    confirmTitle: "Turn on")
                if ok { settings.prefs.messagesEnabled = true }
            }
            .buttonStyle(LNButtonStyle(prominent: true))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: On

    private var enabledView: some View {
        VStack(alignment: .leading, spacing: 10) {
            controls
            noticesCard
            favouritesCard
            connectCard
        }
        .padding(.trailing, 6)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("\(hub.unreadCount) unread", systemImage: "message.fill").lnFont(14, .bold)
                Spacer()
                Button { hub.openMessagesApp() } label: { Label("Open Messages", systemImage: "arrow.up.right.square") }
                    .buttonStyle(LNButtonStyle(prominent: true))
                Button("Mark all read") { hub.markAllRead() }.buttonStyle(LNButtonStyle())
                Button("Clear") { hub.clearAll() }.buttonStyle(LNButtonStyle())
            }
            HStack(spacing: 18) {
                Toggle("Do Not Disturb (hide previews, keep count)", isOn: $settings.prefs.messagesDoNotDisturb)
                Toggle("Show previews", isOn: $settings.prefs.messagesShowPreviews)
            }
            HStack(spacing: 18) {
                Toggle("Remember notices after quitting", isOn: Binding(
                    get: { settings.prefs.messagesRemember },
                    set: { settings.prefs.messagesRemember = $0; hub.persistIfNeeded() }
                ))
                Button("Turn the hub off") { settings.prefs.messagesEnabled = false }.buttonStyle(LNButtonStyle())
            }
            if !settings.prefs.messagesShowPreviews {
                Text("Previews are off, so preview text is not even stored.").lnFont(10.5).foregroundStyle(.secondary)
            }
        }
        .lnFont(12)
        .card()
    }

    private var noticesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle("Notices")
            if hub.notices.isEmpty {
                Text("Nothing yet. Notices appear here when a Shortcut or link you set up sends one.")
                    .lnFont(11).foregroundStyle(.secondary)
            }
            ForEach(hub.notices.prefix(20)) { notice in
                HStack(spacing: 8) {
                    Circle().fill(notice.isRead ? Color.clear : Color.blue).frame(width: 8, height: 8)
                        .accessibilityLabel(notice.isRead ? "Read" : "Unread")
                    Image(systemName: icon(for: notice.source))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(notice.sender) · \(notice.source)").lnFont(12, .semibold)
                        Text(hub.previewsVisible
                             ? (notice.preview.isEmpty ? "(no preview)" : notice.preview)
                             : "Preview hidden")
                            .lnFont(11).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Text(notice.receivedAt, style: .relative).lnFont(10).foregroundStyle(.secondary)
                    Button("Open") { hub.markRead(notice); hub.open(notice) }.buttonStyle(LNButtonStyle())
                }
                .contentShape(Rectangle())
                .onTapGesture { hub.markRead(notice) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func icon(for source: String) -> String {
        source.lowercased().contains("message") ? "message.fill" : "bubble.left.fill"
    }

    // MARK: Favourites

    @State private var favName = ""
    @State private var favHandle = ""
    @State private var favApp = ""

    private var favouritesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle("Favourite contacts and apps")
            ForEach(hub.favourites) { fav in
                HStack {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                    Text(fav.name).lnFont(12, .semibold)
                    Text(fav.appName.isEmpty ? "Messages" : fav.appName).lnFont(10.5).foregroundStyle(.secondary)
                    Spacer()
                    Button("Open") { hub.open(fav) }.buttonStyle(LNButtonStyle(prominent: true))
                    Button { hub.removeFavourite(fav) } label: { Image(systemName: "trash") }
                        .buttonStyle(.plain).accessibilityLabel("Remove \(fav.name)")
                }
            }
            HStack {
                TextField("Name", text: $favName).textFieldStyle(.roundedBorder).frame(width: 110)
                TextField("Phone or Apple ID email", text: $favHandle).textFieldStyle(.roundedBorder)
                TextField("App (blank = Messages)", text: $favApp).textFieldStyle(.roundedBorder).frame(width: 150)
                Button("Add") {
                    let name = favName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    hub.addFavourite(MessageFavourite(name: name, handle: favHandle, appName: favApp))
                    favName = ""; favHandle = ""; favApp = ""
                }
                .buttonStyle(LNButtonStyle(prominent: true))
            }
            Text("You type these yourself, so LifeNotch never needs access to your Contacts. They are only used to open a chat.")
                .lnFont(10).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: Connecting sources

    private var connectCard: some View {
        DisclosureGroup("How do I connect a source?") {
            VStack(alignment: .leading, spacing: 6) {
                Text("""
                     LifeNotch can't watch other apps, so YOU decide what is sent to it:

                     1. In the Shortcuts app, build a shortcut or automation that ends with the action "Add a Message Notice to LifeNotch" (needs the app built with Xcode), or "Open URLs" with the link below.
                     2. Fill in the app name, sender and (optionally) a preview.

                     The link contains a private token, so other web pages can't fake notices. Keep it private.
                     """)
                    .lnFont(11)
                Text(hub.exampleLink).lnFont(10, design: .monospaced).textSelection(.enabled)
                HStack {
                    Button("Copy example link") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(hub.exampleLink, forType: .string)
                    }
                    .buttonStyle(LNButtonStyle())
                    Button("Make a new token") { hub.regenerateToken() }.buttonStyle(LNButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
        .lnFont(12, .medium)
        .card()
    }
}
