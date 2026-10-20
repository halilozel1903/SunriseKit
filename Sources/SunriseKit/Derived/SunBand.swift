import Foundation

/// When the sun is above one altitude on a day: rising and setting times, either of which may be missing.
struct SunBand: Hashable, Sendable {
    var rising: Date?
    var setting: Date?
    /// Only meaningful when both times are missing: whether the sun stays above the altitude.
    var alwaysAbove: Bool

    /// From the API's times for this altitude. Where the API reports neither, the sun stays on one side of the
    /// altitude all day, and the geometry tells which.
    init(altitude: Double, rising: Date?, setting: Date?, geometry: SolarGeometry) {
        self.rising = rising
        self.setting = setting
        if rising == nil, setting == nil {
            let middle = (geometry.noonAltitude + geometry.midnightAltitude) / 2
            if geometry.midnightAltitude > altitude {
                alwaysAbove = true
            } else if geometry.noonAltitude < altitude {
                alwaysAbove = false
            } else {
                // The geometry says the sun crosses it, by very little; the API says it does not.
                alwaysAbove = middle > altitude
            }
        } else {
            alwaysAbove = false
            // One side only: fill the other from the geometry when it lies on the next or previous day.
            if case let .times(computedRising, computedSetting) = geometry.crossing(altitude: altitude) {
                if self.rising == nil { self.rising = computedRising }
                if self.setting == nil { self.setting = computedSetting }
            }
        }
    }

    /// From the geometry alone, for altitudes the API does not report.
    init(altitude: Double, geometry: SolarGeometry) {
        switch geometry.crossing(altitude: altitude) {
        case let .times(rising, setting):
            self.rising = rising
            self.setting = setting
            alwaysAbove = false
        case .alwaysAbove:
            alwaysAbove = true
        case .alwaysBelow:
            alwaysAbove = false
        }
    }

    /// Whether the sun never reaches the altitude.
    var isAlwaysBelow: Bool {
        rising == nil && setting == nil && !alwaysAbove
    }

    /// Whether the sun never sinks below the altitude.
    var isAlwaysAbove: Bool {
        rising == nil && setting == nil && alwaysAbove
    }

    func contains(_ date: Date) -> Bool {
        switch (rising, setting) {
        case let (rising?, setting?):
            rising <= setting ? (date >= rising && date < setting) : (date >= rising || date < setting)
        case let (rising?, nil):
            date >= rising
        case let (nil, setting?):
            date < setting
        case (nil, nil):
            alwaysAbove
        }
    }
}

extension SunTimes {
    var astronomicalBand: SunBand {
        SunBand(altitude: -18, rising: astronomicalTwilightBegin, setting: astronomicalTwilightEnd, geometry: geometry)
    }

    var nauticalBand: SunBand {
        SunBand(altitude: -12, rising: nauticalTwilightBegin, setting: nauticalTwilightEnd, geometry: geometry)
    }

    var civilBand: SunBand {
        SunBand(altitude: -6, rising: civilTwilightBegin, setting: civilTwilightEnd, geometry: geometry)
    }

    var sunBand: SunBand {
        SunBand(altitude: SolarGeometry.horizonAltitude, rising: sunrise, setting: sunset, geometry: geometry)
    }

    func computedBand(_ altitude: Double) -> SunBand {
        SunBand(altitude: altitude, geometry: geometry)
    }
}
