import SunriseKit
import SwiftUI

/// The day from midnight to midnight as coloured phases, with a marker at `now` when it falls on this day.
public struct DayTimelineBar: View {
    let times: SunTimes
    let now: Date?
    var height: CGFloat

    public init(times: SunTimes, now: Date? = nil, height: CGFloat = 8) {
        self.times = times
        self.now = now
        self.height = height
    }

    public var body: some View {
        Canvas { context, size in
            let timeline = times.timeline
            let shape = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: size.height / 2)
            context.clip(to: shape)
            for segment in timeline.segments {
                let rect = CGRect(x: size.width * segment.start, y: 0,
                                  width: size.width * segment.length + 0.5, height: size.height)
                context.fill(Path(rect), with: .color(segment.phase.color))
            }
            if let now, now >= timeline.start, now < timeline.end {
                let x = size.width * timeline.fraction(at: now)
                let marker = CGRect(x: x - 1.5, y: 0, width: 3, height: size.height)
                context.fill(Path(marker), with: .color(.white))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Daylight within the day: a bright bar from sunrise to sunset over a dark one, for comparing days.
public struct DaylightBar: View {
    let times: SunTimes

    public init(times: SunTimes) {
        self.times = times
    }

    public var body: some View {
        Canvas { context, size in
            let timeline = times.timeline
            let shape = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: size.height / 2)
            context.clip(to: shape)
            context.fill(shape, with: .color(SunPhase.night.color))
            if let golden = times.goldenHour.morning.map({ $0.start }), let end = times.goldenHour.evening?.end {
                let start = timeline.fraction(at: golden)
                let rect = CGRect(x: size.width * start, y: 0,
                                  width: size.width * (timeline.fraction(at: end) - start), height: size.height)
                context.fill(Path(rect), with: .color(SunPhase.goldenHour.color.opacity(0.55)))
            }
            if let daylight = times.daylight {
                let start = timeline.fraction(at: daylight.start)
                let rect = CGRect(x: size.width * start, y: 0,
                                  width: size.width * (timeline.fraction(at: daylight.end) - start), height: size.height)
                context.fill(Path(rect), with: .linearGradient(
                    Gradient(colors: [SunPalette.golden, SunPalette.sun, SunPalette.golden]),
                    startPoint: CGPoint(x: rect.minX, y: 0),
                    endPoint: CGPoint(x: rect.maxX, y: 0)
                ))
            }
        }
        .accessibilityHidden(true)
    }
}
