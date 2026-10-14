import SwiftUI

// AutomationsView.swift
// Scheduled AI prompts.

struct AutomationsView: View {
    @EnvironmentObject private var model: AutomationsModel
    @State private var name = ""
    @State private var prompt = ""
    @State private var time = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                SectionTitle("New automation")
                TextField("Name, e.g. Morning brief", text: $name).textFieldStyle(.roundedBorder)
                TextField("What should the AI do?", text: $prompt, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(3...5)
                DatePicker("Every day at", selection: $time, displayedComponents: .hourAndMinute)
                Button("Add (asks first)") {
                    let c = Calendar.current.dateComponents([.hour, .minute], from: time)
                    if model.add(name: name, prompt: prompt, hour: c.hour ?? 8, minute: c.minute ?? 0) { name = ""; prompt = "" }
                }
                .buttonStyle(LNButtonStyle(prominent: true)).disabled(prompt.isEmpty)
                if !model.message.isEmpty { Text(model.message).lnFont(10.5).foregroundStyle(.orange) }
                Text("Runs only while LifeNotch is open. Sends just your prompt to your AI provider. Needs an AI key or Ollama.")
                    .lnFont(9.5).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .frame(width: 250, alignment: .topLeading)
            .card()

            ScrollView {
                VStack(spacing: 6) {
                    if model.items.isEmpty {
                        EmptyStateView(icon: "clock.badge.checkmark", title: "No automations", message: "Add one on the left.")
                    }
                    ForEach(model.items) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.name).lnFont(12.5, .semibold)
                                Text(String(format: "%02d:%02d", item.hour, item.minute)).lnFont(10.5).foregroundStyle(.secondary)
                                Spacer()
                                Toggle("", isOn: Binding(get: { item.enabled }, set: { _ in model.toggle(item) })).labelsHidden()
                                Button("Run now") { Task { await model.run(item) } }
                                    .buttonStyle(LNButtonStyle()).disabled(model.runningID != nil)
                                Button { model.delete(item) } label: { Image(systemName: "trash") }.buttonStyle(.plain)
                            }
                            Text(item.prompt).lnFont(10.5).foregroundStyle(.secondary).lineLimit(2)
                            if model.runningID == item.id { ProgressView().controlSize(.small) }
                            if !item.lastResult.isEmpty {
                                Text(item.lastResult).lnFont(11).textSelection(.enabled)
                                    .padding(6).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.08)))
                                AIBadge()
                            }
                        }
                        .card(padding: 8)
                    }
                }
            }
        }
    }
}
