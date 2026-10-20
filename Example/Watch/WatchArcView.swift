import SunriseKit
import SunriseUI
import SwiftUI

/// The sun's path today with the sun where it is now, the phase and a countdown to the next event.
struct WatchArcView: View {
    @Environment(SunStore.self) private var store

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let city = store.selected
            let now = context.date
            if let times = store.day(in: city, at: now) {
                let phase = times.phase(at: now)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(city.name)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(city.localTime(now))
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    SunArcView(times: times, now: now, lineWidth: 2.5)
                        .frame(height: 64)
                    Label(phase.title, systemImage: phase.symbolName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(phase.accent)
                        .lineLimit(1)
                    if let event = store.nextEvent(in: city, after: now) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(event.kind.title.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("in " + SunFormat.countdown(event.countdown(from: now)))
                                    .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                                Text(SunFormat.time(event.date, in: city.timeZone))
                                    .font(.system(size: 12).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        }
                    }
                    HStack(spacing: 10) {
                        Label(SunFormat.time(times.sunrise, in: city.timeZone), systemImage: "sunrise.fill")
                        Label(SunFormat.time(times.sunset, in: city.timeZone), systemImage: "sunset.fill")
                    }
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .labelStyle(CompactLabelStyle())
                }
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(WatchSky(phase: phase))
            } else {
                WatchLoadingView()
            }
        }
    }
}

/// An icon tinted gold next to its text, close together.
struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
                .foregroundStyle(SunPalette.golden)
            configuration.title
        }
    }
}
