import Foundation

/// A stretch of time, such as this evening's golden hour.
public struct SunWindow: Hashable, Sendable, Codable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    public var duration: TimeInterval {
        end.timeIntervalSince(start)
    }

    public func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }

    /// How far through the window `date` is, from 0 to 1.
    public func progress(at date: Date) -> Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, date.timeIntervalSince(start) / duration))
    }
}

/// A morning and an evening window of one day. Either is `nil` when the sun never passes through that band.
public struct DayWindows: Hashable, Sendable, Codable {
    public let morning: SunWindow?
    public let evening: SunWindow?

    public init(morning: SunWindow?, evening: SunWindow?) {
        self.morning = morning
        self.evening = evening
    }

    /// Both windows, morning first.
    public var all: [SunWindow] {
        [morning, evening].compactMap { $0 }
    }

    /// Whether neither window happens.
    public var isEmpty: Bool {
        morning == nil && evening == nil
    }

    /// The window containing `date`, or else the next one to start after it.
    public func current(orNextAfter date: Date) -> SunWindow? {
        all.first { $0.contains(date) } ?? all.first { $0.start > date }
    }
}

/// The sun altitudes that bound the golden and blue hours.
///
/// Photographers place the golden hour between 4° below and 6° above the horizon, and the blue hour between 6°
/// and 4° below it, which makes the blue hour the darker part of civil twilight. Change the altitudes to use another
/// definition.
public struct GoldenHourDefinition: Hashable, Sendable {
    /// Where the golden hour starts in the morning and ends in the evening (and the blue hour ends and starts).
    public var lowerAltitude: Double
    /// Where the golden hour ends in the morning and starts in the evening.
    public var upperAltitude: Double

    public init(lowerAltitude: Double = -4, upperAltitude: Double = 6) {
        self.lowerAltitude = lowerAltitude
        self.upperAltitude = upperAltitude
    }

    /// -4° to 6°.
    public static let standard = GoldenHourDefinition()
}

extension SunTimes {
    /// The morning and evening golden hours: warm, low light with long shadows.
    ///
    /// When the sun stays in the band through solar noon or midnight (in winter near the polar circles, or on a
    /// white night) the windows meet there. `nil` windows mean the sun never enters the band.
    public func goldenHour(_ definition: GoldenHourDefinition = .standard) -> DayWindows {
        windows(lower: computedBand(definition.lowerAltitude), upper: computedBand(definition.upperAltitude))
    }

    /// The golden hours with the standard definition.
    public var goldenHour: DayWindows {
        goldenHour(.standard)
    }

    /// The morning and evening blue hours: from civil twilight (-6°) to the start of the golden hour (-4°).
    public func blueHour(_ definition: GoldenHourDefinition = .standard) -> DayWindows {
        windows(lower: civilBand, upper: computedBand(definition.lowerAltitude))
    }

    /// The blue hours with the standard definition.
    public var blueHour: DayWindows {
        blueHour(.standard)
    }

    /// The civil twilights: from civil dawn to sunrise and from sunset to civil dusk.
    public var civilTwilight: DayWindows {
        windows(lower: civilBand, upper: sunBand)
    }

    /// The nautical twilights: between 12° and 6° below the horizon.
    public var nauticalTwilight: DayWindows {
        windows(lower: nauticalBand, upper: civilBand)
    }

    /// The astronomical twilights: between 18° and 12° below the horizon.
    public var astronomicalTwilight: DayWindows {
        windows(lower: astronomicalBand, upper: nauticalBand)
    }

    /// Daylight, from sunrise to sunset; the whole day in midnight sun and `nil` in polar night.
    public var daylight: SunWindow? {
        switch sunStatus {
        case .midnightSun:
            return SunWindow(start: startOfDay, end: endOfDay)
        case .polarNight:
            return nil
        case .normal:
            let band = sunBand
            let start = band.rising ?? startOfDay
            let end = band.setting ?? endOfDay
            return end > start ? SunWindow(start: start, end: end) : nil
        }
    }

    /// The windows when the sun is between the altitudes of `lower` and `upper`.
    func windows(lower: SunBand, upper: SunBand) -> DayWindows {
        let solarMidnightBefore = solarNoon.addingTimeInterval(-43_200)
        let solarMidnightAfter = solarNoon.addingTimeInterval(43_200)
        guard !lower.isAlwaysBelow, !upper.isAlwaysAbove else {
            return DayWindows(morning: nil, evening: nil)
        }
        let morningStart = lower.rising ?? solarMidnightBefore
        let morningEnd = upper.rising ?? solarNoon
        let eveningStart = upper.setting ?? solarNoon
        let eveningEnd = lower.setting ?? solarMidnightAfter
        return DayWindows(
            morning: morningEnd > morningStart ? SunWindow(start: morningStart, end: morningEnd) : nil,
            evening: eveningEnd > eveningStart ? SunWindow(start: eveningStart, end: eveningEnd) : nil
        )
    }
}
