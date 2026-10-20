import Foundation

/// Whether the sun rises and sets on a day.
public enum SunStatus: String, Hashable, Sendable, Codable {
    /// The sun rises and sets.
    case normal
    /// Polar day: the sun stays above the horizon all day.
    case midnightSun
    /// Polar night: the sun stays below the horizon all day.
    case polarNight

    /// Whether the sun neither rises nor sets.
    public var isPolar: Bool {
        self != .normal
    }

    public var title: String {
        switch self {
        case .normal: "Sunrise and sunset"
        case .midnightSun: "Midnight sun"
        case .polarNight: "Polar night"
        }
    }
}

/// The sun times of one day at one place, as the API reports them.
///
/// An event that does not happen that day is `nil`: a sunrise in polar night, a sunset in midnight sun or the end
/// of nautical twilight in a white night. (The API sends `1970-01-01T00:00:01+00:00` for these; SunriseKit turns
/// that marker into `nil`.) ``sunStatus`` tells polar day from polar night, and ``dayLength`` is 24 hours or zero
/// for them instead of the API's `0` for both.
public struct SunTimes: Hashable, Sendable, Codable {
    /// The local day these times belong to.
    public let day: CalendarDay
    public let coordinate: Coordinate
    /// The time zone the API expressed the times in (`tzid`), used for local days and formatting.
    public let timeZone: TimeZone

    public let sunrise: Date?
    public let sunset: Date?
    /// When the sun is highest. Always present, even in polar day and night.
    public let solarNoon: Date
    /// Seconds between sunrise and sunset; 86 400 in midnight sun and 0 in polar night.
    public let dayLength: TimeInterval

    /// The sun is 6° below the horizon in the morning: enough light for most things outdoors.
    public let civilTwilightBegin: Date?
    public let civilTwilightEnd: Date?
    /// 12° below the horizon: the horizon at sea becomes visible.
    public let nauticalTwilightBegin: Date?
    public let nauticalTwilightEnd: Date?
    /// 18° below the horizon: the sky starts to brighten; before this it is fully dark.
    public let astronomicalTwilightBegin: Date?
    public let astronomicalTwilightEnd: Date?

    /// Whether the sun rises and sets, or stays up or down all day.
    public let sunStatus: SunStatus
    /// `true` when the API rejected the time zone (`INVALID_TZID`) and the request accepted UTC times instead.
    public internal(set) var usedUTCFallback: Bool

    public init(
        day: CalendarDay,
        coordinate: Coordinate,
        timeZone: TimeZone,
        sunrise: Date?,
        sunset: Date?,
        solarNoon: Date,
        dayLength: TimeInterval,
        civilTwilightBegin: Date?,
        civilTwilightEnd: Date?,
        nauticalTwilightBegin: Date?,
        nauticalTwilightEnd: Date?,
        astronomicalTwilightBegin: Date?,
        astronomicalTwilightEnd: Date?
    ) {
        self.day = day
        self.coordinate = coordinate
        self.timeZone = timeZone
        self.sunrise = sunrise
        self.sunset = sunset
        self.solarNoon = solarNoon
        self.civilTwilightBegin = civilTwilightBegin
        self.civilTwilightEnd = civilTwilightEnd
        self.nauticalTwilightBegin = nauticalTwilightBegin
        self.nauticalTwilightEnd = nauticalTwilightEnd
        self.astronomicalTwilightBegin = astronomicalTwilightBegin
        self.astronomicalTwilightEnd = astronomicalTwilightEnd
        self.usedUTCFallback = false

        let status: SunStatus
        if sunrise != nil || sunset != nil {
            status = .normal
        } else {
            // Both markers: decide from the sun's height at noon.
            let geometry = SolarGeometry(latitude: coordinate.latitude, solarNoon: solarNoon)
            status = geometry.noonAltitude > SolarGeometry.horizonAltitude ? .midnightSun : .polarNight
        }
        self.sunStatus = status

        switch status {
        case .midnightSun:
            self.dayLength = 86_400
        case .polarNight:
            self.dayLength = 0
        case .normal:
            if dayLength > 0 {
                self.dayLength = dayLength
            } else if let sunrise, let sunset, sunset > sunrise {
                self.dayLength = sunset.timeIntervalSince(sunrise)
            } else {
                self.dayLength = max(0, dayLength)
            }
        }
    }

    /// The sun's position over this day, from the coordinate and the solar noon.
    public var geometry: SolarGeometry {
        SolarGeometry(latitude: coordinate.latitude, solarNoon: solarNoon)
    }

    /// The sun's height above the horizon at `date`, in degrees (negative below it).
    public func altitude(at date: Date) -> Double {
        geometry.altitude(at: date)
    }

    /// Local midnight at the start of ``day``.
    public var startOfDay: Date {
        day.startDate(in: timeZone)
    }

    /// Local midnight at the end of ``day`` (23 or 25 hours later on a daylight saving day).
    public var endOfDay: Date {
        day.adding(days: 1).startDate(in: timeZone)
    }
}
