import Foundation

// MarketsModel.swift
// A small stock / index watchlist. Prices come from Stooq (free, no account or key) and are DELAYED, so
// this is for a quick look only, not trading and not financial advice. Only the symbols you typed are sent.
// Your watchlist is saved on this Mac (watchlist.json).

struct Quote: Identifiable, Equatable {
    let symbol: String
    let price: Double
    let open: Double
    let date: String
    var id: String { symbol }
    var changePercent: Double { open > 0 ? (price - open) / open * 100 : 0 }
}

final class MarketsModel: ObservableObject {
    @Published private(set) var symbols: [String]
    @Published private(set) var quotes: [Quote] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var updated: Date?

    private static let fileName = "watchlist.json"

    init() {
        symbols = LocalStore.load([String].self, name: Self.fileName) ?? ["aapl.us", "msft.us", "nvda.us", "^spx", "^ndq"]
    }

    /// "AAPL" -> "aapl.us"; symbols that already have a market suffix or start with ^ are kept.
    static func normalise(_ raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard !s.isEmpty, s.count <= 12, s.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "." || $0 == "^" || $0 == "-" }) else { return nil }
        return (s.contains(".") || s.hasPrefix("^")) ? s : s + ".us"
    }

    static func displayName(_ symbol: String) -> String {
        symbol.hasPrefix("^") ? symbol.dropFirst().uppercased() : (symbol.split(separator: ".").first.map { $0.uppercased() } ?? symbol.uppercased())
    }

    func add(_ raw: String) {
        guard let symbol = Self.normalise(raw), !symbols.contains(symbol), symbols.count < 20 else { return }
        symbols.append(symbol)
        LocalStore.save(symbols, name: Self.fileName)
    }

    func remove(_ symbol: String) {
        symbols.removeAll { $0 == symbol }
        quotes.removeAll { $0.symbol == symbol }
        LocalStore.save(symbols, name: Self.fileName)
    }

    /// Pure parsing of Stooq's CSV (easy to test). Columns: Symbol,Date,Time,Open,High,Low,Close,Volume
    static func parse(_ csv: String) -> [Quote] {
        csv.split(whereSeparator: \.isNewline).dropFirst().compactMap { line in
            let f = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 7, let open = Double(f[3]), let close = Double(f[6]) else { return nil }
            return Quote(symbol: f[0].lowercased(), price: close, open: open, date: f[1])
        }
    }

    @MainActor
    func refresh() async {
        guard !isLoading, !symbols.isEmpty else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        let list = symbols.joined(separator: ",")
        guard let url = URL(string: "https://stooq.com/q/l/?s=\(list)&f=sd2t2ohlcv&h&e=csv") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let parsed = Self.parse(String(decoding: data, as: UTF8.self))
            quotes = symbols.compactMap { symbol in parsed.first { $0.symbol == symbol } }
            updated = Date()
            if quotes.isEmpty { error = "No prices came back. Check the symbols." }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
