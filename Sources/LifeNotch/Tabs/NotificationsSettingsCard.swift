import SwiftUI

// NotificationsSettingsCard.swift
// Settings > Notifications. Every kind is OFF until you switch it on. macOS asks for permission
// at that moment (and only then). Notifications need the real LifeNotch.app (see Scripts/build_app.sh).

struct NotificationsSettingsCard: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var assignments: AssignmentStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Notifications (all off until you choose)")
            if !NotificationManager.shared.isAvailable {
                Label("Notifications only work when LifeNotch is run as an app (Scripts/build_app.sh).",
                      systemImage: "info.circle")
                    .lnFont(10.5).foregroundStyle(.secondary)
            }
            Toggle("Remind me before assignments are due (24 h and 1 h before)", isOn: toggle(\.assignmentReminders) {
                assignments.rescheduleReminders()
            })
        }
        .card()
    }

    /// A switch that asks macOS for notification permission when you turn it ON.
    private func toggle(_ keyPath: WritableKeyPath<Preferences, Bool>, after: @escaping () -> Void) -> Binding<Bool> {
        Binding(
            get: { settings.prefs[keyPath: keyPath] },
            set: { newValue in
                guard newValue else {
                    settings.prefs[keyPath: keyPath] = false
                    after()
                    return
                }
                NotificationManager.shared.requestAuthorization { granted in
                    settings.prefs[keyPath: keyPath] = granted
                    after()
                    if !granted {
                        ModalHelper.info(title: "Notifications are off",
                                         message: "macOS did not allow notifications for LifeNotch (or it isn't running as LifeNotch.app). You can allow them in System Settings > Notifications.")
                    }
                }
            }
        )
    }
}
