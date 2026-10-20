import Foundation

/// One local day laid out from 0 (midnight) to 1 (the next midnight), for drawing an arc, a ring or a bar.
public struct DayTimeline: Hashable, Sendable {
    /// A stretch of the day with one ``SunPhase``.
    public struct Segment: Hashable, Sendable, Identifiable {
        public let phase: SunPhase
        public let start: Double
        public let end: Double

        public var id: Double {
            start
        }

        public var length: Double {
            end - start
        }
    }

    public let start: Date
    public let end: Date
    /// The day in phases, in order, covering 0 to 1 without gaps.
    public let segments: [Segment]

    public init(_ times: SunTimes, definition: GoldenHourDefinition = .standard) {
        let start = times.startOfDay
        let end = times.endOfDay
        self.start = start
        self.end = end
        let length = end.timeIntervalSince(start)

        var boundaries = [start, end]
        boundaries += times.events(definition: definition)
            .filter { $0.kind != .solarNoon && $0.date > start && $0.date < end }
            .map(\.date)
        boundaries.sort()

        var segments: [Segment] = []
        for (from, to) in zip(boundaries, boundaries.dropFirst()) where to > from {
            let middle = from.addingTimeInterval(to.timeIntervalSince(from) / 2)
            let phase = times.phase(at: middle, definition: definition)
            let startFraction = from.timeIntervalSince(start) / length
            let endFraction = to.timeIntervalSince(start) / length
            if let last = segments.last, last.phase == phase {
                segments[segments.count - 1] = Segment(phase: phase, start: last.start, end: endFraction)
            } else {
                segments.append(Segment(phase: phase, start: startFraction, end: endFraction))
            }
        }
        self.segments = segments
    }

    /// Where `date` falls in the day, from 0 to 1 (clamped).
    public func fraction(at date: Date) -> Double {
        let length = end.timeIntervalSince(start)
        guard length > 0 else { return 0 }
        return min(1, max(0, date.timeIntervalSince(start) / length))
    }

    /// The moment at `fraction` of the day.
    public func date(at fraction: Double) -> Date {
        start.addingTimeInterval(end.timeIntervalSince(start) * fraction)
    }

    /// The phase at `fraction` of the day.
    public func phase(at fraction: Double) -> SunPhase? {
        segments.first { fraction >= $0.start && fraction < $0.end }?.phase ?? segments.last?.phase
    }
}

extension SunTimes {
    /// This day laid out from midnight to midnight.
    public var timeline: DayTimeline {
        DayTimeline(self)
    }
}
