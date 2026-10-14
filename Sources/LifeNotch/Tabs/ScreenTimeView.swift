import SwiftUI

// ScreenTimeView.swift
// Which apps you used today, and a 7-day overview. Needs you to switch it on first.

struct ScreenTimeView: View {
    @EnvironmentObject private var model: ScreenTimeModel
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        if !settings.prefs.screenTimeEnabled {
            VStack(spacing: 10) {
                EmptyStateView(icon: "hourglass", title: "Screen Time is off",
                               message: "LifeNotch can keep its own record of which app you use and for how long. It saves only app names and minutes on this Mac, never window titles or what you do. (Apple's own Screen Time data is private.)")
                Button("Turn on") {
                    if ConsentGate.request(.trackAppUsage, settings: settings,
                                           explanation: "LifeNotch will note which app is in front and for how long. It records app names and seconds only, saved on this Mac for 30 days. You can turn it off or erase it any time.") {
                        settings.prefs.screenTimeEnabled = true
                    }
                }
                .buttonStyle(LNButtonStyle(prominent: true))
            }
            .frame(maxWidth: .infinity)
        } else {
            TimelineView(.periodic(from: .now, by: 30)) { _ in content }
        }
    }

    private var content: some View {
        let today = model.today()
        let total = today.reduce(0) { $0 + $1.seconds }
        let maxSeconds = max(today.first?.seconds ?? 1, 1)
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    SectionTitle("Today")
                    Spacer()
                    Text(ScreenTimeModel.text(seconds: total)).lnFont(14, .bold)
                }
                ScrollView {
                    VStack(spacing: 5) {
                        ForEach(Array(today.prefix(12))) { entry in
                            HStack {
                                Text(entry.app).lnFont(11.5).lineLimit(1).frame(width: 110, alignment: .leading)
                                GeometryReader { proxy in
                                    Capsule().fill(Color.accentColor.opacity(0.7))
                                        .frame(width: max(4, proxy.size.width * entry.seconds / maxSeconds))
                                }
                                .frame(height: 8)
                                Text(ScreenTimeModel.text(seconds: entry.seconds)).lnFont(10.5).monospacedDigit().frame(width: 52, alignment: .trailing)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .card()

            VStack(alignment: .leading, spacing: 6) {
                SectionTitle("Last 7 days")
                ForEach(model.totals(lastDays: 7)) { item in
                    HStack {
                        Text(item.day.formatted(.dateTime.weekday(.abbreviated))).lnFont(11).frame(width: 36, alignment: .leading)
                        Text(ScreenTimeModel.text(seconds: item.seconds)).lnFont(11, .semibold).monospacedDigit()
                    }
                }
                Spacer(minLength: 0)
                Button("Turn off") { settings.prefs.screenTimeEnabled = false }.buttonStyle(LNButtonStyle())
                Button("Erase all") {
                    if ModalHelper.confirm(title: "Erase Screen Time history?", message: "This deletes LifeNotch's own usage record. Nothing else changes.", confirmTitle: "Erase", destructive: true) { model.eraseAll() }
                }
                .buttonStyle(LNButtonStyle())
            }
            .frame(width: 170, alignment: .topLeading)
            .card()
        }
    }
}
