import Foundation

/// A moment in the sun's day.
public struct SunEvent: Hashable, Sendable, Codable, Identifiable {
    public enum Kind: String, CaseIterable, Hashable, Sendable, Codable {
        case astronomicalDawn
        case nauticalDawn
        case civilDawn
        /// The blue hour ends and the morning golden hour starts.
        case goldenHourMorningStart
        case sunrise
        case goldenHourMorningEnd
        case solarNoon
        case goldenHourEveningStart
        case sunset
        /// The evening golden hour ends and the blue hour starts.
        case goldenHourEveningEnd
        case civilDusk
        case nauticalDusk
        case astronomicalDusk

        public var title: String {
            switch self {
            case .astronomicalDawn: "Astronomical dawn"
            case .nauticalDawn: "Nautical dawn"
            case .civilDawn: "Civil dawn"
            case .goldenHourMorningStart: "Golden hour"
            case .sunrise: "Sunrise"
            case .goldenHourMorningEnd: "Golden hour ends"
            case .solarNoon: "Solar noon"
            case .goldenHourEveningStart: "Golden hour"
            case .sunset: "Sunset"
            case .goldenHourEveningEnd: "Blue hour"
            case .civilDusk: "Civil dusk"
            case .nauticalDusk: "Nautical dusk"
            case .astronomicalDusk: "Astronomical dusk"
            }
        }

        /// An SF Symbol.
        public var symbolName: String {
            switch self {
            case .astronomicalDawn, .nauticalDawn: "sparkles"
            case .civilDawn: "sun.horizon"
            case .goldenHourMorningStart, .goldenHourMorningEnd, .goldenHourEveningStart: "sun.haze.fill"
            case .sunrise: "sunrise.fill"
            case .solarNoon: "sun.max.fill"
            case .sunset: "sunset.fill"
            case .goldenHourEveningEnd, .civilDusk: "sun.horizon.fill"
            case .nauticalDusk, .astronomicalDusk: "moon.stars.fill"
            }
        }
    }

    public let kind: Kind
    public let date: Date

    public init(kind: Kind, date: Date) {
        self.kind = kind
        self.date = date
    }

    public var id: String {
        kind.rawValue + "-" + String(Int(date.timeIntervalSince1970))
    }

    /// Seconds from `now` until the event; negative once it has passed.
    public func countdown(from now: Date) -> TimeInterval {
        date.timeIntervalSince(now)
    }
}

extension SunTimes {
    /// Every event that happens on this day, in time order. Golden hour boundaries come from
    /// ``goldenHour(_:)``'s altitudes; the rest are the API's times.
    public func events(definition: GoldenHourDefinition = .standard) -> [SunEvent] {
        let lower = computedBand(definition.lowerAltitude)
        let upper = computedBand(definition.upperAltitude)
        let candidates: [(SunEvent.Kind, Date?)] = [
            (.astronomicalDawn, astronomicalTwilightBegin),
            (.nauticalDawn, nauticalTwilightBegin),
            (.civilDawn, civilTwilightBegin),
            (.goldenHourMorningStart, lower.rising),
            (.sunrise, sunrise),
            (.goldenHourMorningEnd, upper.rising),
            (.solarNoon, solarNoon),
            (.goldenHourEveningStart, upper.setting),
            (.sunset, sunset),
            (.goldenHourEveningEnd, lower.setting),
            (.civilDusk, civilTwilightEnd),
            (.nauticalDusk, nauticalTwilightEnd),
            (.astronomicalDusk, astronomicalTwilightEnd),
        ]
        return candidates
            .compactMap { kind, date in date.map { SunEvent(kind: kind, date: $0) } }
            .sorted { $0.date < $1.date }
    }

    /// The first event after `date` on this day, or `nil` when the day has none left.
    public func nextEvent(after date: Date, definition: GoldenHourDefinition = .standard) -> SunEvent? {
        events(definition: definition).first { $0.date > date }
    }
}

extension Sequence where Element == SunTimes {
    /// The first event after `date` across these days, so the countdown keeps going after the last dusk: pass today
    /// and tomorrow.
    public func nextEvent(after date: Date, definition: GoldenHourDefinition = .standard) -> SunEvent? {
        flatMap { $0.events(definition: definition) }
            .filter { $0.date > date }
            .min { $0.date < $1.date }
    }

    /// The day that contains `date` (local midnight to midnight), if any.
    public func day(containing date: Date) -> SunTimes? {
        first { date >= $0.startOfDay && date < $0.endOfDay }
    }
}
