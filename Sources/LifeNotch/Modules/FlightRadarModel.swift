import Foundation
import CoreGraphics

// FlightRadarModel.swift
// Shows aircraft currently flying near a city you type, from OpenSky Network (a free community service,
// no account needed). Only the city name (to Open-Meteo, to find its position) and a rectangle of
// map coordinates (to OpenSky) are sent. No location permission is used. It only refreshes while the
// Flight Radar tab is open.

struct Aircraft: Identifiable, Equatable {
    let id: String
    let callsign: String
    let country: String
    let latitude: Double
    let longitude: Double
    let altitudeMeters: Double?
    let speedMps: Double?
    let heading: Double?
    let onGround: Bool

    var altitudeText: String { altitudeMeters.map { "\(Int($0 * 3.28084).formatted()) ft" } ?? "–" }
    var speedText: String { speedMps.map { "\(Int($0 * 1.94384)) kt" } ?? "–" }
}

final class FlightRadarModel: ObservableObject {
    @Published private(set) var aircraft: [Aircraft] = []
    @Published private(set) var center: (lat: Double, lon: Double)?
    @Published private(set) var placeName = ""
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var updated: Date?

    /// Rough bounding box around a point (pure maths, easy to test).
    static func box(lat: Double, lon: Double, rangeKm: Double) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        let dLat = rangeKm / 111.0
        let dLon = rangeKm / (111.0 * max(cos(lat * .pi / 180), 0.1))
        return (lat - dLat, lat + dLat, lon - dLon, lon + dLon)
    }

    /// Position of an aircraft on a radar of side `size`, centred at (lat, lon), covering `rangeKm` each way.
    static func radarPoint(lat: Double, lon: Double, centerLat: Double, centerLon: Double, rangeKm: Double, size: CGFloat) -> CGPoint {
        let box = box(lat: centerLat, lon: centerLon, rangeKm: rangeKm)
        let x = (lon - box.minLon) / (box.maxLon - box.minLon)
        let y = 1 - (lat - box.minLat) / (box.maxLat - box.minLat)
        return CGPoint(x: CGFloat(x) * size, y: CGFloat(y) * size)
    }

    static func parse(_ data: Data) -> [Aircraft] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let states = root["states"] as? [[Any]] else { return [] }
        return states.compactMap { s in
            guard s.count > 10, let icao = s[0] as? String,
                  let lon = s[5] as? Double, let lat = s[6] as? Double else { return nil }
            let call = (s[1] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
            return Aircraft(id: icao, callsign: call.isEmpty ? icao : call, country: (s[2] as? String) ?? "",
                            latitude: lat, longitude: lon,
                            altitudeMeters: s[7] as? Double, speedMps: s[9] as? Double, heading: s[10] as? Double,
                            onGround: (s[8] as? Bool) ?? false)
        }
    }

    @MainActor
    func refresh(city: String, rangeKm: Int) async {
        let name = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            if center == nil || placeName != name {
                try await geocode(name)
            }
            guard let c = center else { return }
            let b = Self.box(lat: c.lat, lon: c.lon, rangeKm: Double(rangeKm))
            let urlText = "https://opensky-network.org/api/states/all?lamin=\(b.minLat)&lomin=\(b.minLon)&lamax=\(b.maxLat)&lomax=\(b.maxLon)"
            guard let url = URL(string: urlText) else { return }
            var request = URLRequest(url: url, timeoutInterval: 15)
            request.setValue("LifeNotch", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 429 {
                error = "OpenSky is rate-limiting free users. Try again in a minute."
                return
            }
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                error = "OpenSky answered with an error (\(http.statusCode))."
                return
            }
            aircraft = Self.parse(data).filter { !$0.onGround }.sorted { ($0.altitudeMeters ?? 0) > ($1.altitudeMeters ?? 0) }
            updated = Date()
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    private func geocode(_ name: String) async throws {
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=1&language=en&format=json") else { return }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let first = (root["results"] as? [[String: Any]])?.first,
              let lat = first["latitude"] as? Double, let lon = first["longitude"] as? Double else {
            center = nil
            throw FlightError.cityNotFound
        }
        center = (lat, lon)
        placeName = name
    }
}

enum FlightError: LocalizedError {
    case cityNotFound
    var errorDescription: String? { "Couldn't find that city." }
}
