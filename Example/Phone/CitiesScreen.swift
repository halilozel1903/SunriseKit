import SunriseKit
import SunriseUI
import SwiftUI

/// Every city with today's sunrise, sunset, day length, the phase now and the day as a bar.
struct CitiesScreen: View {
    @Environment(SunStore.self) private var store
    @Environment(LocationProvider.self) private var location

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            List {
                Section {
                    if let city = location.city {
                        NavigationLink(value: city) {
                            CityRow(city: city, now: context.date)
                        }
                    } else {
                        Button {
                            location.request()
                        } label: {
                            Label(location.isLocating ? "Locating…" : "Use My Location", systemImage: "location.fill")
                        }
                        if let message = location.message {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listRowBackground(Theme.card)

                Section {
                    ForEach(City.all) { city in
                        NavigationLink(value: city) {
                            CityRow(city: city, now: context.date)
                        }
                    }
                } footer: {
                    SunriseAttributionView()
                        .padding(.top, 8)
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
        }
        .navigationTitle("Daybreak")
        .daybreakNavigationBar()
        .task {
            await store.loadAll(City.all)
        }
        .task(id: location.city) {
            if let city = location.city {
                await store.load(city)
            }
        }
        .refreshable {
            await store.loadAll(City.all)
        }
    }
}

/// One city: name, local time and phase, today's times and the day bar.
struct CityRow: View {
    let city: City
    let now: Date

    @Environment(SunStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(city.name)
                        .font(.headline)
                    Text(city.country + " · " + city.localTime(now))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let times = store.day(in: city, at: now) {
                    SunPhaseBadge(times.phase(at: now), compact: true)
                }
            }
            if let times = store.day(in: city, at: now) {
                HStack(spacing: 14) {
                    TimeLabel(symbol: "sunrise.fill", text: SunFormat.time(times.sunrise, in: city.timeZone))
                    TimeLabel(symbol: "sunset.fill", text: SunFormat.time(times.sunset, in: city.timeZone))
                    TimeLabel(symbol: "hourglass", text: SunFormat.duration(times.dayLength))
                }
                DayTimelineBar(times: times, now: now, height: 8)
            } else if case let .failed(message) = store.state(of: city) {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
    }
}

/// A gold symbol and a time.
struct TimeLabel: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .foregroundStyle(SunPalette.golden)
            Text(text)
                .monospacedDigit()
        }
        .font(.subheadline)
    }
}
