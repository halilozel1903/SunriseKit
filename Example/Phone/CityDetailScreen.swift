import SunriseKit
import SunriseUI
import SwiftUI

/// One city: the sun arc now, the next event, golden and blue hours, twilights and the next seven days.
struct CityDetailScreen: View {
    let city: City

    @Environment(SunStore.self) private var store

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            ScrollView {
                VStack(spacing: 14) {
                    if let times = store.day(in: city, at: now), store.hasLoaded(city, days: 7) {
                        NowCard(city: city, times: times, now: now, next: store.nextEvent(in: city, after: now))
                        HoursCard(times: times, timeZone: city.timeZone)
                        TwilightCard(times: times, timeZone: city.timeZone)
                        WeekCard(city: city, days: store.week(in: city))
                        SunriseAttributionView()
                            .padding(.vertical, 6)
                    } else {
                        PhoneLoadingView(failure: failure) {
                            Task { await store.load(city, days: 7, force: true) }
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.background)
        }
        .navigationTitle(city.name)
        .daybreakNavigationBar()
        .task {
            await store.load(city, days: 7)
        }
    }

    private var failure: String? {
        if case let .failed(message) = store.state(of: city) { return message }
        return nil
    }
}

/// The arc with the sun now, the phase and the countdown to the next event.
struct NowCard: View {
    let city: City
    let times: SunTimes
    let now: Date
    let next: SunEvent?

    var body: some View {
        let phase = times.phase(at: now)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SunPhaseBadge(phase)
                Spacer()
                Text(city.localTime(now) + " local")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            SunArcView(times: times, now: now, lineWidth: 3)
                .frame(height: 150)
            HStack {
                Text("00:00")
                Spacer()
                Text("12:00")
                Spacer()
                Text("24:00")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.tertiary)
            if let next {
                HStack(alignment: .firstTextBaseline) {
                    Label(next.kind.title, systemImage: next.kind.symbolName)
                        .font(.headline)
                        .foregroundStyle(SunPalette.golden)
                    Spacer()
                    Text("in " + SunFormat.countdown(next.countdown(from: now)))
                        .font(.title2.weight(.bold).monospacedDigit())
                }
                Text("at " + SunFormat.time(next.date, in: city.timeZone))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if times.sunStatus.isPolar {
                Label(times.sunStatus.title, systemImage: "globe.europe.africa.fill")
                    .font(.subheadline)
            }
        }
        .padding(14)
        .background(
            LinearGradient(colors: [phase.color.opacity(0.55), Theme.card], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }
}

/// Golden and blue hours, morning and evening.
struct HoursCard: View {
    let times: SunTimes
    let timeZone: TimeZone

    var body: some View {
        Card("Golden & blue hour", systemImage: "sun.haze.fill") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("")
                    Text("Morning").font(.caption).foregroundStyle(.secondary)
                    Text("Evening").font(.caption).foregroundStyle(.secondary)
                }
                row("Golden", SunPalette.golden, times.goldenHour)
                row("Blue", SunPalette.blue, times.blueHour)
            }
            .font(.subheadline.monospacedDigit())
        }
    }

    private func row(_ title: String, _ color: Color, _ windows: DayWindows) -> some View {
        GridRow {
            Label(title, systemImage: "circle.fill")
                .labelStyle(DotLabelStyle(color: color))
            Text(text(windows.morning))
            Text(text(windows.evening))
        }
    }

    private func text(_ window: SunWindow?) -> String {
        guard let window else { return "—" }
        return SunFormat.time(window.start, in: timeZone) + "–" + SunFormat.time(window.end, in: timeZone)
    }
}

/// A coloured dot before the title.
struct DotLabelStyle: LabelStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            configuration.title
        }
    }
}

/// Dawn and dusk of each twilight, sunrise, sunset, solar noon and the day length.
struct TwilightCard: View {
    let times: SunTimes
    let timeZone: TimeZone

    var body: some View {
        Card("Twilight", systemImage: "sun.horizon.fill") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("")
                    Text("Dawn").font(.caption).foregroundStyle(.secondary)
                    Text("Dusk").font(.caption).foregroundStyle(.secondary)
                }
                row("Astronomical", .astronomicalTwilight, times.astronomicalTwilightBegin, times.astronomicalTwilightEnd)
                row("Nautical", .nauticalTwilight, times.nauticalTwilightBegin, times.nauticalTwilightEnd)
                row("Civil", .civilTwilight, times.civilTwilightBegin, times.civilTwilightEnd)
                row("Sunrise / set", .goldenHour, times.sunrise, times.sunset)
            }
            .font(.subheadline.monospacedDigit())
            Divider().overlay(Color.white.opacity(0.15))
            HStack {
                Label("Solar noon " + SunFormat.time(times.solarNoon, in: timeZone), systemImage: "sun.max.fill")
                Spacer()
                Label(SunFormat.duration(times.dayLength), systemImage: "hourglass")
            }
            .font(.subheadline.monospacedDigit())
        }
    }

    private func row(_ title: String, _ phase: SunPhase, _ begin: Date?, _ end: Date?) -> some View {
        GridRow {
            Label(title, systemImage: "circle.fill")
                .labelStyle(DotLabelStyle(color: phase == .goldenHour ? SunPalette.golden : phase.accent))
            Text(SunFormat.time(begin, in: timeZone))
            Text(SunFormat.time(end, in: timeZone))
        }
    }
}

/// The next seven days: sunrise, sunset, day length and its change, and daylight as a bar.
struct WeekCard: View {
    let city: City
    let days: [SunTimes]

    var body: some View {
        Card("Next 7 days", systemImage: "calendar") {
            VStack(spacing: 10) {
                ForEach(Array(days.enumerated()), id: \.element.day) { index, times in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(index == 0 ? "Today" : SunFormat.weekday(times.day, in: city.timeZone))
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 64, alignment: .leading)
                            TimeLabel(symbol: "sunrise.fill", text: SunFormat.time(times.sunrise, in: city.timeZone))
                            Spacer(minLength: 4)
                            TimeLabel(symbol: "sunset.fill", text: SunFormat.time(times.sunset, in: city.timeZone))
                        }
                        HStack(spacing: 8) {
                            DaylightBar(times: times)
                                .frame(height: 6)
                            Text(SunFormat.duration(times.dayLength))
                                .font(.caption.monospacedDigit())
                            if index > 0 {
                                Text(SunFormat.change(times.dayLength - days[index - 1].dayLength))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(times.dayLength >= days[index - 1].dayLength ? Color.green : Color.orange)
                                    .frame(width: 62, alignment: .trailing)
                            } else {
                                Text("").frame(width: 62)
                            }
                        }
                    }
                }
            }
        }
    }
}
