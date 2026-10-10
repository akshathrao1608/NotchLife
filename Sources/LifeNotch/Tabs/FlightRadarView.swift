import SwiftUI

// FlightRadarView.swift
// A little radar of aircraft flying near the city you choose. Live data from OpenSky Network.

struct FlightRadarView: View {
    @EnvironmentObject private var model: FlightRadarModel
    @EnvironmentObject private var settings: AppSettings
    @State private var cityDraft = ""

    var body: some View {
        let prefs = settings.prefs
        Group {
            if prefs.flightCity.isEmpty {
                VStack(spacing: 8) {
                    EmptyStateView(icon: "airplane", title: "Which city?",
                                   message: "Type a city to see planes flying nearby. Only the city name and a map rectangle are sent (to Open-Meteo and OpenSky). No location permission is used.")
                    HStack {
                        TextField("City", text: $cityDraft).textFieldStyle(.roundedBorder).frame(width: 200).onSubmit(setCity)
                        Button("Show planes", action: setCity).buttonStyle(LNButtonStyle(prominent: true)).disabled(cityDraft.isEmpty)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    radar(prefs)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(model.aircraft.count) planes near \(prefs.flightCity)").lnFont(12, .semibold)
                            Spacer()
                            Button { Task { await model.refresh(city: prefs.flightCity, rangeKm: prefs.flightRangeKm) } } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.plain).disabled(model.isLoading).help("Refresh")
                            Button("Change city") { settings.prefs.flightCity = "" }.buttonStyle(.plain).lnFont(10.5)
                        }
                        Picker("Range", selection: $settings.prefs.flightRangeKm) {
                            Text("30 km").tag(30); Text("60 km").tag(60); Text("120 km").tag(120); Text("250 km").tag(250)
                        }
                        .pickerStyle(.segmented).labelsHidden()
                        if let error = model.error { Text(error).lnFont(10.5).foregroundStyle(.orange) }
                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(model.aircraft.prefix(40)) { plane in
                                    HStack {
                                        Image(systemName: "airplane").rotationEffect(.degrees((plane.heading ?? 90) - 90))
                                        Text(plane.callsign).lnFont(11.5, .semibold)
                                        Text(plane.country).lnFont(10).foregroundStyle(.secondary).lineLimit(1)
                                        Spacer()
                                        Text("\(plane.altitudeText) · \(plane.speedText)").lnFont(10).monospacedDigit().foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        Text("Live data from OpenSky Network (community receivers, can have gaps)" + (model.updated.map { " · updated " + $0.formatted(date: .omitted, time: .shortened) } ?? ""))
                            .lnFont(9.5).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task(id: prefs.flightCity + String(prefs.flightRangeKm)) {
            // Refresh now, then every 20 s, only while this tab is on screen.
            while !Task.isCancelled, !settings.prefs.flightCity.isEmpty {
                await model.refresh(city: settings.prefs.flightCity, rangeKm: settings.prefs.flightRangeKm)
                try? await Task.sleep(nanoseconds: 20_000_000_000)
            }
        }
    }

    private func setCity() { settings.prefs.flightCity = cityDraft.trimmingCharacters(in: .whitespaces) }

    private func radar(_ prefs: Preferences) -> some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().stroke(Color.green.opacity(0.5), lineWidth: 1)
                Circle().stroke(Color.green.opacity(0.3), lineWidth: 1).scaleEffect(0.66)
                Circle().stroke(Color.green.opacity(0.2), lineWidth: 1).scaleEffect(0.33)
                if let c = model.center {
                    ForEach(model.aircraft) { plane in
                        let p = FlightRadarModel.radarPoint(lat: plane.latitude, lon: plane.longitude,
                                                            centerLat: c.lat, centerLon: c.lon,
                                                            rangeKm: Double(prefs.flightRangeKm), size: size)
                        Image(systemName: "airplane")
                            .font(.system(size: 9))
                            .rotationEffect(.degrees((plane.heading ?? 90) - 90))
                            .foregroundStyle(Color.green)
                            .position(p)
                    }
                }
                Circle().fill(Color.white).frame(width: 5, height: 5)
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .background(Circle().fill(Color.black.opacity(0.35)))
        }
        .frame(width: 190, height: 190)
        .accessibilityLabel("Radar showing \(model.aircraft.count) aircraft")
    }
}
