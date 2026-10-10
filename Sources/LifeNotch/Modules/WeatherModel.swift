import Foundation

// WeatherModel.swift
// Current weather from Open-Meteo (a free weather service that needs no account or key).
// You type a city name; LifeNotch sends ONLY that city name to look up its coordinates, then the
// coordinates to get the weather. No location permission is used. Nothing is sent until you set a city.

final class WeatherModel: ObservableObject {
    @Published private(set) var temperature: Double?
    @Published private(set) var symbol = "cloud.fill"
    @Published private(set) var summary = ""
    @Published private(set) var place = ""
    @Published private(set) var error: String?
    @Published private(set) var isLoading = false
    @Published private(set) var updated: Date?

    private let usesFahrenheit = !Locale.current.usesMetricSystem

    var temperatureText: String {
        guard let t = temperature else { return "–" }
        return "\(Int(t.rounded()))°" + (usesFahrenheit ? "F" : "C")
    }

    @MainActor
    func refreshIfStale(city: String) async {
        if let updated = updated, Date().timeIntervalSince(updated) < 900, place.lowercased().contains(city.lowercased()) { return }
        await refresh(city: city)
    }

    @MainActor
    func refresh(city: String) async {
        let name = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        isLoading = true
        error = nil
        do {
            guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let geoURL = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=1&language=en&format=json") else {
                throw WeatherError.notFound
            }
            let geoData = try await fetch(geoURL)
            guard let geo = (try? JSONSerialization.jsonObject(with: geoData)) as? [String: Any],
                  let first = (geo["results"] as? [[String: Any]])?.first,
                  let lat = first["latitude"] as? Double, let lon = first["longitude"] as? Double else {
                throw WeatherError.notFound
            }
            let country = (first["country"] as? String) ?? ""
            place = [(first["name"] as? String) ?? name, country].filter { !$0.isEmpty }.joined(separator: ", ")

            let unit = usesFahrenheit ? "&temperature_unit=fahrenheit" : ""
            guard let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code,is_day&timezone=auto\(unit)") else {
                throw WeatherError.badData
            }
            let data = try await fetch(url)
            guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let current = json["current"] as? [String: Any],
                  let temp = current["temperature_2m"] as? Double else {
                throw WeatherError.badData
            }
            let code = (current["weather_code"] as? Int) ?? 0
            let isDay = ((current["is_day"] as? Int) ?? 1) == 1
            temperature = temp
            (symbol, summary) = Self.describe(code: code, isDay: isDay)
            updated = Date()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private enum WeatherError: LocalizedError {
        case notFound, badData
        var errorDescription: String? {
            switch self {
            case .notFound: return "Couldn't find that city."
            case .badData: return "The weather service sent something unexpected."
            }
        }
    }

    private func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw WeatherError.badData }
        return data
    }

    /// WMO weather codes -> an icon and a few words.
    static func describe(code: Int, isDay: Bool) -> (String, String) {
        switch code {
        case 0: return (isDay ? "sun.max.fill" : "moon.stars.fill", "Clear")
        case 1, 2: return (isDay ? "cloud.sun.fill" : "cloud.moon.fill", "Partly cloudy")
        case 3: return ("cloud.fill", "Cloudy")
        case 45, 48: return ("cloud.fog.fill", "Fog")
        case 51...57: return ("cloud.drizzle.fill", "Drizzle")
        case 61...67: return ("cloud.rain.fill", "Rain")
        case 71...77: return ("cloud.snow.fill", "Snow")
        case 80...82: return ("cloud.heavyrain.fill", "Showers")
        case 85, 86: return ("cloud.snow.fill", "Snow showers")
        case 95...99: return ("cloud.bolt.rain.fill", "Thunderstorm")
        default: return ("cloud.fill", "Cloudy")
        }
    }
}
