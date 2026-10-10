import SwiftUI

// QuickAddView.swift
// Type one sentence like "dentist friday 3pm" and add it as a calendar event, a reminder or a to-do.
// Also shows your next calendar events once you press Connect.

struct QuickAddView: View {
    @EnvironmentObject private var calendar: CalendarModel
    @EnvironmentObject private var todos: TodoStore
    @EnvironmentObject private var settings: AppSettings

    @State private var text = ""
    @State private var status = ""

    var body: some View {
        let parsed = QuickAddParser.parse(text)
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("Quick Add")
                TextField("e.g. Lunch with Sam tomorrow 1pm", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addEvent(parsed) }
                if !text.isEmpty {
                    Label(parsed.date.map { "\(parsed.title) · \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "\(parsed.title) · no date found",
                          systemImage: "sparkle.magnifyingglass")
                        .lnFont(11).foregroundStyle(.secondary)
                }
                HStack {
                    Button("Calendar event") { addEvent(parsed) }
                        .disabled(parsed.date == nil || !calendar.connected || parsed.title.isEmpty)
                    Button("Reminder") { addReminder(parsed) }.disabled(parsed.title.isEmpty)
                    Button("To-do") { todos.add(parsed.title); status = "Added to your To-Do list."; text = "" }
                        .disabled(parsed.title.isEmpty)
                }
                .buttonStyle(LNButtonStyle(prominent: false))
                if !status.isEmpty { Text(status).lnFont(11).foregroundStyle(.secondary) }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .card()

            VStack(alignment: .leading, spacing: 6) {
                SectionTitle("Up next")
                if !calendar.connected {
                    Text("Connect to see your next events. LifeNotch asks first, and macOS asks too.")
                        .lnFont(10.5).foregroundStyle(.secondary)
                    Button("Connect calendar") { Task { await calendar.connect(settings: settings) } }
                        .buttonStyle(LNButtonStyle(prominent: true))
                    if !calendar.message.isEmpty { Text(calendar.message).lnFont(10).foregroundStyle(.orange) }
                } else if calendar.upcoming.isEmpty {
                    Text("Nothing in the next 7 days.").lnFont(11).foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(calendar.upcoming) { entry in
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(entry.title).lnFont(12, .semibold).lineLimit(1)
                                    Text(entry.isAllDay ? entry.start.formatted(date: .abbreviated, time: .omitted)
                                                        : entry.start.formatted(date: .abbreviated, time: .shortened))
                                        .lnFont(10).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .frame(width: 210, alignment: .topLeading)
            .card()
        }
        .onAppear { calendar.refreshIfAuthorized() }
    }

    private func addEvent(_ parsed: QuickAddParse) {
        guard let date = parsed.date, !parsed.title.isEmpty else { return }
        do {
            try calendar.addEvent(title: parsed.title, start: date)
            status = "Added to your calendar."
            text = ""
        } catch { status = error.localizedDescription }
    }

    private func addReminder(_ parsed: QuickAddParse) {
        Task {
            do {
                try await calendar.addReminder(title: parsed.title, due: parsed.date, settings: settings)
                status = "Added to Reminders."
                text = ""
            } catch { status = error.localizedDescription }
        }
    }
}
