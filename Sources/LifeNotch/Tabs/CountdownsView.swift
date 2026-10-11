import SwiftUI

// CountdownsView.swift
// How many days until the things you care about.

struct CountdownsView: View {
    @EnvironmentObject private var store: CountdownStore
    @State private var title = ""
    @State private var date = Date().addingTimeInterval(7 * 86400)

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("Add one")
                TextField("e.g. Maths exam", text: $title).textFieldStyle(.roundedBorder)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Button("Add") { store.add(title: title, date: date); title = "" }
                    .buttonStyle(LNButtonStyle(prominent: true)).disabled(title.isEmpty)
                Spacer(minLength: 0)
            }
            .frame(width: 230, alignment: .topLeading)
            .card()

            if store.items.isEmpty {
                EmptyStateView(icon: "calendar.badge.clock", title: "Nothing counting down", message: "Add an exam, trip or birthday.")
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(store.sorted) { item in
                            let days = CountdownStore.daysUntil(item.date)
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.title).lnFont(13, .semibold)
                                    Text(item.date.formatted(date: .abbreviated, time: .omitted)).lnFont(10).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(CountdownStore.text(days: days)).lnFont(14, .bold)
                                    .foregroundStyle(days < 0 ? Color.secondary : (days <= 3 ? Color.orange : Color.primary))
                                Button { store.delete(item) } label: { Image(systemName: "trash") }
                                    .buttonStyle(.plain).foregroundStyle(.secondary)
                            }
                            .card(padding: 8)
                        }
                    }
                }
            }
        }
    }
}
