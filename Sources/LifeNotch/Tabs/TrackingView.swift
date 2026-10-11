import SwiftUI
import AppKit

// TrackingView.swift
// Paste a parcel number (opens the carrier's own page) or a flight number (shows the plane if airborne).

struct TrackingView: View {
    @EnvironmentObject private var model: TrackingModel
    @State private var number = ""
    @State private var flightText = ""

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                SectionTitle("Parcels")
                HStack {
                    TextField("Tracking number", text: $number).textFieldStyle(.roundedBorder).onSubmit(track)
                    Button("Track", action: track).buttonStyle(LNButtonStyle(prominent: true)).disabled(number.isEmpty)
                }
                Text("Opens the carrier's own tracking page in your browser. LifeNotch can't show live parcel status itself.")
                    .lnFont(9.5).foregroundStyle(.secondary)
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(model.parcels) { parcel in
                            HStack {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(parcel.number).lnFont(11.5, .semibold).textSelection(.enabled)
                                    Text(TrackingDetect.carrier(for: parcel.number).rawValue).lnFont(9.5).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Open") { open(parcel.number) }.buttonStyle(.plain)
                                Button { model.deleteParcel(parcel) } label: { Image(systemName: "trash") }
                                    .buttonStyle(.plain).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .card()

            VStack(alignment: .leading, spacing: 6) {
                SectionTitle("Flights")
                HStack {
                    TextField("Flight number, e.g. BA117", text: $flightText).textFieldStyle(.roundedBorder)
                        .onSubmit { Task { await model.findFlight(flightText) } }
                    Button("Find") { Task { await model.findFlight(flightText) } }
                        .buttonStyle(LNButtonStyle(prominent: true)).disabled(flightText.isEmpty || model.isLoading)
                }
                if model.isLoading { ProgressView().controlSize(.small) }
                if let plane = model.flight {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(plane.callsign, systemImage: "airplane").lnFont(14, .bold)
                        Text("\(plane.country) · \(plane.altitudeText) · \(plane.speedText)").lnFont(11)
                        Text(String(format: "%.2f°, %.2f°", plane.latitude, plane.longitude)).lnFont(10).foregroundStyle(.secondary)
                        Button("Show on a map") {
                            if let url = URL(string: "https://maps.apple.com/?ll=\(plane.latitude),\(plane.longitude)&q=\(plane.callsign)") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(LNButtonStyle())
                    }
                }
                if !model.flightMessage.isEmpty { Text(model.flightMessage).lnFont(10.5).foregroundStyle(.secondary) }
                Text("Live positions from OpenSky Network; coverage has gaps.").lnFont(9.5).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .frame(width: 250, alignment: .topLeading)
            .card()
        }
    }

    private func track() {
        model.addParcel(number, label: "")
        open(number)
        number = ""
    }

    private func open(_ n: String) {
        if let url = TrackingDetect.carrier(for: n).trackingURL(n) { NSWorkspace.shared.open(url) }
    }
}
