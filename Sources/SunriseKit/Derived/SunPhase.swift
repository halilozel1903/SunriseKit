import Foundation

/// How light it is, from the sun's height. Ordered from darkest to brightest.
public enum SunPhase: Int, CaseIterable, Comparable, Hashable, Sendable, Codable {
    /// The sun is more than 18° below the horizon.
    case night
    /// 18° to 12° below.
    case astronomicalTwilight
    /// 12° to 6° below.
    case nauticalTwilight
    /// 6° to 4° below with the standard definition: the darker part of civil twilight, the blue hour.
    case civilTwilight
    /// 4° below to 6° above: the golden hour, including sunrise and sunset.
    case goldenHour
    /// More than 6° above.
    case day

    public static func < (lhs: SunPhase, rhs: SunPhase) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var title: String {
        switch self {
        case .night: "Night"
        case .astronomicalTwilight: "Astronomical twilight"
        case .nauticalTwilight: "Nautical twilight"
        case .civilTwilight: "Blue hour"
        case .goldenHour: "Golden hour"
        case .day: "Daylight"
        }
    }

    /// A shorter title for small screens.
    public var shortTitle: String {
        switch self {
        case .night: "Night"
        case .astronomicalTwilight: "Astro twilight"
        case .nauticalTwilight: "Nautical"
        case .civilTwilight: "Blue hour"
        case .goldenHour: "Golden hour"
        case .day: "Day"
        }
    }

    /// An SF Symbol.
    public var symbolName: String {
        switch self {
        case .night: "moon.stars.fill"
        case .astronomicalTwilight: "sparkles"
        case .nauticalTwilight: "water.waves"
        case .civilTwilight: "sun.horizon"
        case .goldenHour: "sun.haze.fill"
        case .day: "sun.max.fill"
        }
    }
}

extension SunTimes {
    /// The light at `date` on this day, from the API's twilight times and the golden hour altitudes.
    public func phase(at date: Date, definition: GoldenHourDefinition = .standard) -> SunPhase {
        if computedBand(definition.upperAltitude).contains(date) { return .day }
        if computedBand(definition.lowerAltitude).contains(date) { return .goldenHour }
        if civilBand.contains(date) { return .civilTwilight }
        if nauticalBand.contains(date) { return .nauticalTwilight }
        if astronomicalBand.contains(date) { return .astronomicalTwilight }
        return .night
    }

    /// Whether `date` is before solar noon, so the light is growing.
    public func isMorning(at date: Date) -> Bool {
        date < solarNoon
    }

    /// How far the sun has travelled from sunrise to sunset at `date`, from 0 to 1, or `nil` while it is below the
    /// horizon. In midnight sun this runs over the whole local day.
    public func sunProgress(at date: Date) -> Double? {
        guard let daylight, daylight.contains(date) else { return nil }
        return daylight.progress(at: date)
    }
}
