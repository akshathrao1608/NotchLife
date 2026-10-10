import SwiftUI

// TodoView.swift
// A quick to-do list. Highest priority first; finished items sink to the bottom.

struct TodoView: View {
    @EnvironmentObject private var todos: TodoStore
    @State private var newTitle = ""
    @State private var newPriority: Priority = .medium
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Add a to-do and press Return", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
                    .focused($fieldFocused)
                    .onSubmit(add)
                Picker("Priority", selection: $newPriority) {
                    ForEach(Priority.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden().frame(width: 100)
                Button("Add", action: add).buttonStyle(LNButtonStyle(prominent: true)).disabled(newTitle.isEmpty)
            }
            HStack {
                Text("\(todos.openCount) to do").lnFont(11).foregroundStyle(.secondary)
                Spacer()
                if todos.items.contains(where: { $0.done }) {
                    Button("Clear finished") { todos.clearDone() }.buttonStyle(LNButtonStyle())
                }
            }
            if todos.items.isEmpty {
                EmptyStateView(icon: "checkmark.circle", title: "Nothing to do", message: "Add something above.")
            }
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(todos.sorted) { item in
                        HStack(spacing: 8) {
                            Button { todos.toggle(item) } label: {
                                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 17))
                                    .foregroundStyle(item.done ? Color.green : item.priority.color)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.done ? "Mark \(item.title) as not done" : "Mark \(item.title) as done")
                            Text(item.title).lnFont(12.5).strikethrough(item.done).opacity(item.done ? 0.5 : 1)
                            Spacer()
                            Menu {
                                ForEach(Priority.allCases) { p in
                                    Button(p.title) { todos.setPriority(item, p) }
                                }
                            } label: {
                                Text(item.priority.title).lnFont(10, .semibold).foregroundStyle(item.priority.color)
                            }
                            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                            Button { todos.delete(item) } label: { Image(systemName: "trash") }
                                .buttonStyle(.plain).accessibilityLabel("Delete \(item.title)")
                        }
                        .card(padding: 8)
                    }
                }
                .padding(.trailing, 6)
            }
        }
        .onAppear { fieldFocused = true }
    }

    private func add() {
        todos.add(newTitle, priority: newPriority)
        newTitle = ""
        fieldFocused = true
    }
}
