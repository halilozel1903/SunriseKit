import Foundation

/// When the sun crosses an altitude on a day.
public enum AltitudeCrossing: Hashable, Sendable {
    /// It rises above the altitude at `rising` and sinks below it at `setting`.
    case times(rising: Date, setting: Date)
    /// It stays above the altitude all day.
    case alwaysAbove
    /// It stays below the altitude all day.
    case alwaysBelow
}

/// The sun's path across the sky on one day, from the latitude, the solar noon and the sun's declination
/// (NOAA's solar equations).
///
/// SunriseKit uses it for what the API does not report: the golden and blue hour boundaries (4° below and 6° above
/// the horizon), the sun's height at any moment and, in polar day or night, which of the two it is. The API's own
/// times stay the source for sunrise, sunset and the three twilights.
public struct SolarGeometry: Hashable, Sendable {
    /// The apparent altitude of the sun's centre at sunrise and sunset: refraction and the solar disc's radius.
    public static let horizonAltitude = -0.833

    public let latitude: Double
    public let solarNoon: Date
    /// The sun's declination at solar noon, in degrees.
    public let declination: Double

    public init(latitude: Double, solarNoon: Date) {
        self.latitude = latitude
        self.solarNoon = solarNoon
        self.declination = Self.declination(at: solarNoon)
    }

    /// The sun's declination at `date`, in degrees (NOAA's approximation, good to about 0.01°).
    public static func declination(at date: Date) -> Double {
        let julianDay = date.timeIntervalSince1970 / 86_400 + 2_440_587.5
        let t = (julianDay - 2_451_545) / 36_525
        let meanLongitude = (280.46646 + t * (36_000.76983 + t * 0.0003032)).truncatingRemainder(dividingBy: 360)
        let meanAnomaly = 357.52911 + t * (35_999.05029 - 0.0001537 * t)
        let center = sin(radians(meanAnomaly)) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(radians(2 * meanAnomaly)) * (0.019993 - 0.000101 * t)
            + sin(radians(3 * meanAnomaly)) * 0.000289
        let omega = 125.04 - 1934.136 * t
        let apparentLongitude = meanLongitude + center - 0.00569 - 0.00478 * sin(radians(omega))
        let meanObliquity = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
        let obliquity = meanObliquity + 0.00256 * cos(radians(omega))
        return degrees(asin(sin(radians(obliquity)) * sin(radians(apparentLongitude))))
    }

    /// The sun's highest altitude of the day, at solar noon.
    public var noonAltitude: Double {
        altitude(hourAngle: 0)
    }

    /// The sun's lowest altitude, twelve hours from solar noon.
    public var midnightAltitude: Double {
        altitude(hourAngle: 180)
    }

    /// The sun's altitude at `date`, in degrees.
    public func altitude(at date: Date) -> Double {
        altitude(hourAngle: date.timeIntervalSince(solarNoon) / 3600 * 15)
    }

    /// When the sun crosses `altitude` degrees on this day.
    public func crossing(altitude: Double) -> AltitudeCrossing {
        let phi = Self.radians(latitude)
        let delta = Self.radians(declination)
        let denominator = cos(phi) * cos(delta)
        let numerator = sin(Self.radians(altitude)) - sin(phi) * sin(delta)
        guard abs(denominator) > 1e-12 else {
            return numerator < 0 ? .alwaysAbove : .alwaysBelow
        }
        let cosine = numerator / denominator
        if cosine > 1 { return .alwaysBelow }
        if cosine < -1 { return .alwaysAbove }
        let seconds = Self.degrees(acos(cosine)) / 15 * 3600
        return .times(rising: solarNoon.addingTimeInterval(-seconds), setting: solarNoon.addingTimeInterval(seconds))
    }

    private func altitude(hourAngle: Double) -> Double {
        let phi = Self.radians(latitude)
        let delta = Self.radians(declination)
        let value = sin(phi) * sin(delta) + cos(phi) * cos(delta) * cos(Self.radians(hourAngle))
        return Self.degrees(asin(min(1, max(-1, value))))
    }

    static func radians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }

    static func degrees(_ radians: Double) -> Double {
        radians * 180 / .pi
    }
}
