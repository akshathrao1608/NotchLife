import SwiftUI
import AppKit

// ToolsView.swift
// Little everyday tools: a calculator that answers as you type, a unit converter,
// Keep Awake (stops the screen sleeping for a while) and a colour picker.

struct ToolsView: View {
    @EnvironmentObject private var keepAwake: KeepAwakeModel

    @State private var expression = ""
    @State private var category: UnitCategory = .length
    @State private var fromIndex = 0
    @State private var toIndex = 1
    @State private var amount = "1"
    @State private var pickedHex = ""
    @State private var pickedColor: Color = .clear

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                calculatorCard
                converterCard
                keepAwakeCard
                colorCard
            }
            .padding(.trailing, 6)
        }
    }

    // MARK: Calculator

    private var calculatorCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle("Calculator")
            TextField("Try (12.5 + 7) × 3 or sqrt(2)", text: $expression)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Calculation")
            if let value = Calculator.evaluate(expression) {
                HStack {
                    Text("= " + Calculator.format(value)).font(.system(size: 22, weight: .semibold, design: .rounded)).monospacedDigit()
                    Spacer()
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(Calculator.format(value), forType: .string)
                    }
                    .buttonStyle(LNButtonStyle())
                }
            } else if !expression.isEmpty {
                Text("Keep typing…").lnFont(11).foregroundStyle(.secondary)
            }
            Text("+ − × ÷ ^ % ( ), sqrt abs sin cos tan ln log pi e").lnFont(9.5).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: Converter

    private var converterCard: some View {
        let units = category.units
        let safeFrom = min(fromIndex, units.count - 1)
        let safeTo = min(toIndex, units.count - 1)
        let result: String = {
            guard let value = Double(amount.replacingOccurrences(of: ",", with: ".")) else { return "–" }
            return Calculator.format(UnitCategory.convert(value, from: units[safeFrom].unit, to: units[safeTo].unit))
        }()
        return VStack(alignment: .leading, spacing: 6) {
            SectionTitle("Unit converter")
            Picker("Type", selection: $category) {
                ForEach(UnitCategory.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .onChange(of: category) { _ in fromIndex = 0; toIndex = 1 }
            HStack {
                TextField("Amount", text: $amount).textFieldStyle(.roundedBorder).frame(width: 80)
                Picker("From", selection: $fromIndex) {
                    ForEach(Array(units.enumerated()), id: \.offset) { index, unit in Text(unit.name).tag(index) }
                }
                .labelsHidden()
            }
            HStack {
                Text("= " + result).font(.system(size: 18, weight: .semibold, design: .rounded)).monospacedDigit().frame(minWidth: 80, alignment: .leading)
                Picker("To", selection: $toIndex) {
                    ForEach(Array(units.enumerated()), id: \.offset) { index, unit in Text(unit.name).tag(index) }
                }
                .labelsHidden()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: Keep awake

    private var keepAwakeCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle("Keep awake")
            if keepAwake.isOn {
                Label(keepAwake.until.map { "Awake until " + $0.formatted(date: .omitted, time: .shortened) } ?? "Awake until you stop it",
                      systemImage: "cup.and.saucer.fill")
                    .lnFont(12, .semibold)
                Button("Stop") { keepAwake.stop() }.buttonStyle(LNButtonStyle(destructive: true))
            } else {
                Text("Stops the screen from sleeping for a while.").lnFont(11).foregroundStyle(.secondary)
                HStack {
                    Button("30 min") { keepAwake.start(minutes: 30) }
                    Button("1 hour") { keepAwake.start(minutes: 60) }
                    Button("2 hours") { keepAwake.start(minutes: 120) }
                    Button("Until I stop it") { keepAwake.start(minutes: nil) }
                }
                .buttonStyle(LNButtonStyle())
            }
            Text("Changes no system settings. It ends by itself when you quit LifeNotch.").lnFont(9.5).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: Colour picker

    private var colorCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle("Colour picker")
            HStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(pickedHex.isEmpty ? Color.primary.opacity(0.1) : pickedColor)
                    .frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.primary.opacity(0.25)))
                VStack(alignment: .leading) {
                    Text(pickedHex.isEmpty ? "No colour yet" : pickedHex).font(.system(size: 16, weight: .semibold, design: .monospaced))
                    if !pickedHex.isEmpty {
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(pickedHex, forType: .string)
                        }
                        .buttonStyle(LNButtonStyle())
                    }
                }
            }
            Button("Pick a colour from the screen") {
                let sampler = NSColorSampler()
                sampler.show { color in
                    guard let color = color, let rgb = color.usingColorSpace(.sRGB) else { return }
                    let r = Int((rgb.redComponent * 255).rounded())
                    let g = Int((rgb.greenComponent * 255).rounded())
                    let b = Int((rgb.blueComponent * 255).rounded())
                    pickedHex = String(format: "#%02X%02X%02X", r, g, b)
                    pickedColor = Color(nsColor: rgb)
                }
            }
            .buttonStyle(LNButtonStyle(prominent: true))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
