import SwiftUI

// HabitsView.swift
// Tick off today's habits and watch the streak grow.

struct HabitsView: View {
    @EnvironmentObject private var store: HabitStore
    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("New habit, e.g. Read 10 pages", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Button("Add", action: add).buttonStyle(LNButtonStyle(prominent: true)).disabled(newName.isEmpty)
            }
            if store.habits.isEmpty {
                EmptyStateView(icon: "checkmark.seal", title: "No habits yet", message: "Add one above. Tick it each day to build a streak.")
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(store.habits) { habit in
                            let done = store.isDone(habit)
                            let streak = HabitStore.streak(habit)
                            HStack {
                                Button { store.toggleToday(habit) } label: {
                                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(done ? Color.green : Color.secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(habit.name), \(done ? "done" : "not done") today")
                                Text(habit.name).lnFont(13, .medium)
                                Spacer()
                                Label("\(streak)", systemImage: "flame.fill")
                                    .lnFont(11, .semibold).foregroundStyle(streak > 0 ? Color.orange : Color.secondary)
                                    .accessibilityLabel("\(streak) day streak")
                                Button { store.delete(habit) } label: { Image(systemName: "trash") }
                                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Delete habit")
                            }
                            .card(padding: 8)
                        }
                    }
                }
            }
        }
    }

    private func add() { store.add(newName); newName = "" }
}
