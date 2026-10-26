import SunriseKit
import SunriseUI
import SwiftUI

/// Today's golden hour as a card and every twilight phase, with the blue hour below them.
struct WatchGoldenView: View {
    @Environment(SunStore.self) private var store

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let city = store.selected
            let now = context.date
            if let times = store.day(in: city, at: now) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        GoldenHourCard(cityName: city.name, times: times, timeZone: city.timeZone, now: now)
                        TwilightList(times: times, timeZone: city.timeZone)
                        WindowRow(title: "Blue hour", symbol: "sun.horizon", color: SunPalette.blue,
                                  windows: times.blueHour, timeZone: city.timeZone)
                    }
                    .padding(.horizontal, 2)
                }
                .background(WatchSky(phase: .goldenHour).opacity(0.6))
            } else {
                WatchLoadingView()
            }
        }
    }
}

/// The morning and evening golden hours, with the one that is on now or next highlighted.
struct GoldenHourCard: View {
    let cityName: String
    let times: SunTimes
    let timeZone: TimeZone
    let now: Date

    var body: some View {
        let golden = times.goldenHour
        let focus = golden.current(orNextAfter: now)
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Label("Golden hour", systemImage: "sun.haze.fill")
                    .font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 4)
                Text(cityName)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if golden.isEmpty {
                Text(times.sunStatus == .midnightSun ? "The sun stays high all day." : "The sun stays low all day.")
                    .font(.system(size: 12))
            }
            if let morning = golden.morning {
                windowRow("Morning", morning, isFocus: morning == focus)
            }
            if let evening = golden.evening {
                windowRow("Evening", evening, isFocus: evening == focus)
            }
            if let focus {
                Text(focus.contains(now)
                     ? "Now · ends in " + SunFormat.countdown(focus.end.timeIntervalSince(now))
                     : "Starts in " + SunFormat.countdown(focus.start.timeIntervalSince(now)))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.black.opacity(0.7))
            }
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [SunPalette.sun, SunPalette.golden], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private func windowRow(_ title: String, _ window: SunWindow, isFocus: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
            Spacer()
            Text(SunFormat.time(window.start, in: timeZone) + "–" + SunFormat.time(window.end, in: timeZone))
                .font(.system(size: 12, weight: isFocus ? .bold : .regular).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

/// A row with a morning and an evening window.
struct WindowRow: View {
    let title: String
    let symbol: String
    let color: Color
    let windows: DayWindows
    let timeZone: TimeZone

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
            if windows.isEmpty {
                Text("Not today")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            ForEach(windows.all, id: \.start) { window in
                Text(SunFormat.time(window.start, in: timeZone) + "–" + SunFormat.time(window.end, in: timeZone))
                    .font(.system(size: 12).monospacedDigit())
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Dawn and dusk for each kind of twilight.
struct TwilightList: View {
    let times: SunTimes
    let timeZone: TimeZone

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("TWILIGHT · DAWN · DUSK")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            row("Astronomical", SunPhase.astronomicalTwilight, times.astronomicalTwilightBegin, times.astronomicalTwilightEnd)
            row("Nautical", SunPhase.nauticalTwilight, times.nauticalTwilightBegin, times.nauticalTwilightEnd)
            row("Civil", SunPhase.civilTwilight, times.civilTwilightBegin, times.civilTwilightEnd)
            row("Sun", SunPhase.goldenHour, times.sunrise, times.sunset)
            HStack {
                Text("Day length")
                Spacer()
                Text(SunFormat.duration(times.dayLength))
                    .monospacedDigit()
            }
            .font(.system(size: 12))
        }
    }

    private func row(_ title: String, _ phase: SunPhase, _ begin: Date?, _ end: Date?) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(phase.color)
                .frame(width: 7, height: 7)
            Text(title)
                .lineLimit(1)
            Spacer(minLength: 2)
            Text(begin == nil && end == nil ? "None" : SunFormat.time(begin, in: timeZone) + " · " + SunFormat.time(end, in: timeZone))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .font(.system(size: 12))
    }
}
