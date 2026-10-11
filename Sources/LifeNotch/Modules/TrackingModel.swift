import Foundation

// TrackingModel.swift
// "Live tracking" in an honest, key-free way:
//  - Parcels: paste a tracking number; LifeNotch guesses the carrier and opens that carrier's OWN official
//    tracking page in your browser. (Live parcel status inside the app would need each carrier's private
//    business API key, so it isn't faked.) Numbers you save stay on this Mac.
//  - Flights: type a flight number like BA117; if that plane is airborne right now you see where it is,
//    from OpenSky Network. Only the flight number is used to filter the public list; nothing personal is sent.

enum Carrier: String, CaseIterable {
    case ups = "UPS", usps = "USPS", fedex = "FedEx", dhl = "DHL", royalMail = "Royal Mail", amazon = "Amazon", unknown = "Search"

    func trackingURL(_ number: String) -> URL? {
        let n = number.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? number
        switch self {
        case .ups: return URL(string: "https://www.ups.com/track?tracknum=\(n)")
        case .usps: return URL(string: "https://tools.usps.com/go/TrackConfirmAction?tLabels=\(n)")
        case .fedex: return URL(string: "https://www.fedex.com/fedextrack/?trknbr=\(n)")
        case .dhl: return URL(string: "https://www.dhl.com/global-en/home/tracking/tracking-express.html?submit=1&tracking-id=\(n)")
        case .royalMail: return URL(string: "https://www.royalmail.com/track-your-item#/tracking-results/\(n)")
        case .amazon: return URL(string: "https://www.amazon.com/progress-tracker/package")
        case .unknown: return URL(string: "https://parcelsapp.com/en/tracking/\(n)")
        }
    }
}

struct TrackedParcel: Identifiable, Codable, Equatable {
    var id = UUID()
    var number: String
    var label = ""
}

enum TrackingDetect {
    static func carrier(for raw: String) -> Carrier {
        let s = raw.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        func matches(_ pattern: String) -> Bool { s.range(of: "^" + pattern + "$", options: .regularExpression) != nil }
        if matches("1Z[0-9A-Z]{16}") { return .ups }
        if matches("TBA[0-9]{12}") { return .amazon }
        if matches("[A-Z]{2}[0-9]{9}GB") { return .royalMail }
        if matches("[A-Z]{2}[0-9]{9}US") || matches("9[0-9]{19,21}") { return .usps }
        if matches("[0-9]{12}") || matches("[0-9]{15}") { return .fedex }
        if matches("[0-9]{10}") || matches("JJD[0-9]{10,}") { return .dhl }
        return .unknown
    }
}

enum FlightNumber {
    private static let airlines: [String: String] = [
        "BA": "BAW", "AA": "AAL", "DL": "DAL", "UA": "UAL", "WN": "SWA", "AS": "ASA", "B6": "JBU", "AC": "ACA",
        "LH": "DLH", "AF": "AFR", "KL": "KLM", "IB": "IBE", "LX": "SWR", "OS": "AUA", "SK": "SAS", "AY": "FIN",
        "FR": "RYR", "U2": "EZY", "VS": "VIR", "EK": "UAE", "QR": "QTR", "EY": "ETD", "TK": "THY", "SQ": "SIA",
        "CX": "CPA", "QF": "QFA", "NZ": "ANZ", "AI": "AIC", "JL": "JAL", "NH": "ANA", "KE": "KAL", "TP": "TAP",
        "EI": "EIN", "W6": "WZZ", "VY": "VLG", "AZ": "ITY", "LO": "LOT", "SV": "SVA", "ET": "ETH", "MS": "MSR"
    ]

    /// "BA117" or "ba 117" -> "BAW117" (the form planes broadcast). Already-ICAO codes ("BAW117") pass through.
    static func callsign(from raw: String) -> String {
        let s = raw.uppercased().filter { !$0.isWhitespace }
        let two = String(s.prefix(2))
        if let icao = airlines[two], s.count > 2, s[s.index(s.startIndex, offsetBy: 2)].isNumber {
            return icao + s.dropFirst(2)
        }
        return s
    }
}

final class TrackingModel: ObservableObject {
    @Published private(set) var parcels: [TrackedParcel]
    @Published private(set) var flight: Aircraft?
    @Published private(set) var flightMessage = ""
    @Published private(set) var isLoading = false
    private static let fileName = "parcels.json"

    init() { parcels = LocalStore.load([TrackedParcel].self, name: Self.fileName) ?? [] }

    func addParcel(_ number: String, label: String) {
        let n = number.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, !parcels.contains(where: { $0.number == n }) else { return }
        parcels.insert(TrackedParcel(number: n, label: label), at: 0)
        LocalStore.save(parcels, name: Self.fileName)
    }

    func deleteParcel(_ parcel: TrackedParcel) {
        parcels.removeAll { $0.id == parcel.id }
        LocalStore.save(parcels, name: Self.fileName)
    }

    @MainActor
    func findFlight(_ input: String) async {
        let callsign = FlightNumber.callsign(from: input)
        guard !callsign.isEmpty, !isLoading else { return }
        isLoading = true
        flight = nil
        flightMessage = ""
        defer { isLoading = false }
        guard let url = URL(string: "https://opensky-network.org/api/states/all") else { return }
        do {
            var request = URLRequest(url: url, timeoutInterval: 25)
            request.setValue("LifeNotch", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 429 {
                flightMessage = "OpenSky is rate-limiting free users. Try again in a minute."
                return
            }
            let match = FlightRadarModel.parse(data).first { $0.callsign.uppercased().hasPrefix(callsign) }
            if let match = match { flight = match } else {
                flightMessage = "\(callsign) isn't in the air right now (or isn't covered by OpenSky's receivers)."
            }
        } catch {
            flightMessage = error.localizedDescription
        }
    }
}
