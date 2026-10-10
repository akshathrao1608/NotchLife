import SwiftUI

// HomeView.swift
// A quick overview: date, weather (for a city YOU type), battery in plain words, what's due
// next and your to-dos. Pure read-only overview, with shortcuts to the other tabs.

struct HomeView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var weather: WeatherModel
    @EnvironmentObject private var stats: SystemStatsModel
    @EnvironmentObject private var assignments: AssignmentStore
    @EnvironmentObject private var todos: TodoStore
    @EnvironmentObject private var notch: NotchState
    @EnvironmentObject private var calendar: CalendarModel
    @State private var cityDraft = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    dateCard
                    weatherCard
                    batteryCard
                }
                HStack(alignment: .top, spacing: 10) {
                    dueCard
                    todoCard
                }
            }
            .padding(.trailing, 6)
        }
        .onAppear {
            stats.startLightRefresh()
            Task { await refreshWeather() }
        }
    }

    private func refreshWeather() async {
        let city = settings.prefs.weatherCity
        if !city.isEmpty { await weather.refreshIfStale(city: city) }
    }

    // MARK: Cards

    private var dateCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 2) {
                Text(context.date.formatted(.dateTime.weekday(.wide))).lnFont(11).foregroundStyle(.secondary)
                Text(context.date.formatted(.dateTime.day().month(.wide))).lnFont(18, .bold)
                Text(context.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 26, weight: .semibold, design: .rounded)).monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
        .card()
    }

    private var weatherCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle("Weather")
            if settings.prefs.weatherCity.isEmpty {
                Text("Type your city to see the weather. Only the city name is sent to the free Open-Meteo service.")
                    .lnFont(10).foregroundStyle(.secondary)
                HStack {
                    TextField("City", text: $cityDraft).textFieldStyle(.roundedBorder).onSubmit(setCity)
                    Button("Set", action: setCity).buttonStyle(LNButtonStyle(prominent: true)).disabled(cityDraft.isEmpty)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: weather.symbol).font(.system(size: 26)).symbolRenderingMode(.multicolor)
                    VStack(alignment: .leading) {
                        Text(weather.temperatureText).font(.system(size: 24, weight: .semibold, design: .rounded))
                        Text(weather.summary).lnFont(10.5).foregroundStyle(.secondary)
                    }
                }
                Text(weather.place).lnFont(10.5).foregroundStyle(.secondary).lineLimit(1)
                if let error = weather.error { Text(error).lnFont(10).foregroundStyle(.orange) }
                HStack {
                    Button("Refresh") { Task { await weather.refresh(city: settings.prefs.weatherCity) } }.buttonStyle(LNButtonStyle())
                    Button("Change") { settings.prefs.weatherCity = "" }.buttonStyle(LNButtonStyle())
                }
                if weather.isLoading { ProgressView().controlSize(.small) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func setCity() {
        let city = cityDraft.trimmingCharacters(in: .whitespaces)
        guard !city.isEmpty else { return }
        settings.prefs.weatherCity = city
        cityDraft = ""
        Task { await weather.refresh(city: city) }
    }

    private var batteryCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle("Battery")
            if let percent = stats.batteryPercent {
                Text("\(percent)%").font(.system(size: 26, weight: .semibold, design: .rounded)).monospacedDigit()
                ProgressView(value: Double(percent), total: 100)
                Text(stats.batteryWords).lnFont(11).foregroundStyle(.secondary)
            } else {
                Text("No battery (plugged-in Mac)").lnFont(11).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var dueCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                SectionTitle("Due next")
                Spacer()
                Button("All") { notch.selectedTab = .assignments }.buttonStyle(.plain).lnFont(10.5).foregroundStyle(.secondary)
            }
            if let event = calendar.nextEvent {
                HStack {
                    Image(systemName: "calendar").foregroundStyle(.secondary)
                    Text(event.title).lnFont(12).lineLimit(1)
                    Spacer()
                    Text(event.start.formatted(date: .omitted, time: .shortened)).lnFont(10.5, .semibold).foregroundStyle(.secondary)
                }
            }
            if assignments.upcoming.isEmpty {
                Text("Nothing due. 🎉").lnFont(11).foregroundStyle(.secondary)
            }
            ForEach(assignments.upcoming.prefix(3)) { item in
                HStack {
                    Image(systemName: item.isUrgent() ? "exclamationmark.triangle.fill" : "book.closed.fill")
                        .foregroundStyle(item.isUrgent() ? Color.red : Color.secondary)
                    Text(item.title.isEmpty ? "Untitled" : item.title).lnFont(12).lineLimit(1)
                    Spacer()
                    Text(item.dueSummary()).lnFont(10.5, .semibold).foregroundStyle(item.isUrgent() ? Color.red : Color.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var todoCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                SectionTitle("To-do")
                Spacer()
                Button("All") { notch.selectedTab = .todo }.buttonStyle(.plain).lnFont(10.5).foregroundStyle(.secondary)
            }
            let open = todos.sorted.filter { !$0.done }
            if open.isEmpty {
                Text("All done. 🎉").lnFont(11).foregroundStyle(.secondary)
            }
            ForEach(open.prefix(4)) { item in
                HStack {
                    Button { todos.toggle(item) } label: { Image(systemName: "circle").foregroundStyle(item.priority.color) }
                        .buttonStyle(.plain).accessibilityLabel("Mark \(item.title) as done")
                    Text(item.title).lnFont(12).lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
