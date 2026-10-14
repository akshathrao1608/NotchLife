import SwiftUI

// MarketsView.swift
// A tiny delayed-price watchlist. Not financial advice.

struct MarketsView: View {
    @EnvironmentObject private var model: MarketsModel
    @State private var newSymbol = ""

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Add a symbol, e.g. TSLA or ^SPX", text: $newSymbol).textFieldStyle(.roundedBorder).onSubmit(add)
                Button("Add", action: add).buttonStyle(LNButtonStyle(prominent: true)).disabled(newSymbol.isEmpty)
                if model.isLoading { ProgressView().controlSize(.small) }
                LNIconButton(systemName: "arrow.clockwise", label: "Refresh prices") { Task { await model.refresh() } }
            }
            if let error = model.error { Text(error).lnFont(11).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading) }
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(model.quotes) { quote in
                        HStack {
                            Text(MarketsModel.displayName(quote.symbol)).lnFont(13, .bold)
                            Spacer()
                            Text(quote.price.formatted(.number.precision(.fractionLength(2)))).lnFont(13, .semibold).monospacedDigit()
                            Text(String(format: "%+.2f%%", quote.changePercent)).lnFont(11, .semibold).monospacedDigit()
                                .foregroundStyle(quote.changePercent >= 0 ? Color.green : Color.red)
                                .frame(width: 70, alignment: .trailing)
                            Button { model.remove(quote.symbol) } label: { Image(systemName: "xmark.circle.fill") }
                                .buttonStyle(.plain).foregroundStyle(.secondary)
                        }
                        .card(padding: 8)
                    }
                }
            }
            Text("Delayed prices from Stooq. Change is today's move since the open. For a quick look only, not financial advice.")
                .lnFont(9.5).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            while !Task.isCancelled {
                await model.refresh()
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }

    private func add() { model.add(newSymbol); newSymbol = ""; Task { await model.refresh() } }
}
