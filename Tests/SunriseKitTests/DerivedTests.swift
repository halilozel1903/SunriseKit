import Foundation
import Testing
@testable import SunriseKit

/// Expected golden hour boundaries come from NOAA's equations for Istanbul on October 18, 2026.
@Suite("Golden hour, phases, events and timeline")
struct DerivedTests {
    /// Whether two dates are within `seconds` of each other.
    func close(_ lhs: Date?, _ rhs: Date, within seconds: TimeInterval = 30) -> Bool {
        guard let lhs else { return false }
        return abs(lhs.timeIntervalSince(rhs)) <= seconds
    }

    @Test("Golden hour from -4° to 6°")
    func goldenHour() throws {
        let times = try Fixture.istanbulDay()
        let golden = times.goldenHour
        let morning = try #require(golden.morning)
        let evening = try #require(golden.evening)
        #expect(close(morning.start, Fixture.date(2026, 10, 18, 7, 1, 46)))
        #expect(close(morning.end, Fixture.date(2026, 10, 18, 7, 56, 25)))
        #expect(close(evening.start, Fixture.date(2026, 10, 18, 17, 42, 2)))
        #expect(close(evening.end, Fixture.date(2026, 10, 18, 18, 36, 41)))
        let sunrise = try #require(times.sunrise)
        #expect(morning.contains(sunrise))
        let sunset = try #require(times.sunset)
        #expect(evening.contains(sunset))
    }

    @Test("Blue hour from civil dawn to the golden hour")
    func blueHour() throws {
        let times = try Fixture.istanbulDay()
        let morning = try #require(times.blueHour.morning)
        let evening = try #require(times.blueHour.evening)
        #expect(morning.start == times.civilTwilightBegin)
        #expect(close(morning.end, Fixture.date(2026, 10, 18, 7, 1, 46)))
        #expect(close(evening.start, Fixture.date(2026, 10, 18, 18, 36, 41)))
        #expect(evening.end == times.civilTwilightEnd)
        let civil = try #require(times.civilTwilight.morning)
        #expect(civil.end == times.sunrise)
    }

    @Test("A wider golden hour definition starts earlier")
    func customDefinition() throws {
        let times = try Fixture.istanbulDay()
        let wide = GoldenHourDefinition(lowerAltitude: -6, upperAltitude: 10)
        let standard = try #require(times.goldenHour.morning)
        let wider = try #require(times.goldenHour(wide).morning)
        #expect(wider.start < standard.start)
        #expect(wider.end > standard.end)
        let civilDawn = try #require(times.civilTwilightBegin)
        #expect(close(wider.start, civilDawn, within: 60))
    }

    @Test("Phase through the day", arguments: [
        (5, 0, SunPhase.night),
        (6, 0, SunPhase.astronomicalTwilight),
        (6, 30, SunPhase.nauticalTwilight),
        (6, 55, SunPhase.civilTwilight),
        (7, 30, SunPhase.goldenHour),
        (12, 0, SunPhase.day),
        (18, 0, SunPhase.goldenHour),
        (18, 40, SunPhase.civilTwilight),
        (19, 0, SunPhase.nauticalTwilight),
        (19, 30, SunPhase.astronomicalTwilight),
        (21, 0, SunPhase.night),
    ])
    func phases(hour: Int, minute: Int, expected: SunPhase) throws {
        let times = try Fixture.istanbulDay()
        #expect(times.phase(at: Fixture.date(2026, 10, 18, hour, minute)) == expected)
    }

    @Test("Phases in polar day and night")
    func polarPhases() throws {
        let summer = try Fixture.sunTimes("longyearbyen-2026-06-21", coordinate: Fixture.longyearbyen, timeZone: Fixture.longyearbyenZone)
        #expect(summer.phase(at: Fixture.date(2026, 6, 21, 0, 30, in: Fixture.longyearbyenZone)) == .day)
        #expect(summer.goldenHour.isEmpty)
        #expect(summer.daylight?.duration == 86_400)

        let winter = try Fixture.sunTimes("longyearbyen-2026-12-21", coordinate: Fixture.longyearbyen, timeZone: Fixture.longyearbyenZone)
        #expect(winter.phase(at: Fixture.date(2026, 12, 21, 12, 0, in: Fixture.longyearbyenZone)) == .nauticalTwilight)
        #expect(winter.phase(at: Fixture.date(2026, 12, 21, 9, 0, in: Fixture.longyearbyenZone)) == .astronomicalTwilight)
        #expect(winter.phase(at: Fixture.date(2026, 12, 21, 3, 0, in: Fixture.longyearbyenZone)) == .night)
        #expect(winter.goldenHour.isEmpty)
        #expect(winter.blueHour.isEmpty)

        let pole = try Fixture.sunTimes("north-pole-2026-12-21", coordinate: Fixture.northPole, timeZone: TimeZone(identifier: "UTC")!)
        #expect(pole.phase(at: Fixture.date(2026, 12, 21, 12, 0, in: TimeZone(identifier: "UTC")!)) == .night)
    }

    @Test("A white night stays in the golden hour around midnight")
    func whiteNight() throws {
        let times = try Fixture.sunTimes("reykjavik-2026-06-21", coordinate: Fixture.reykjavik, timeZone: Fixture.reykjavikZone)
        #expect(times.phase(at: Fixture.date(2026, 6, 21, 1, 30, in: Fixture.reykjavikZone)) == .goldenHour)
        #expect(times.phase(at: Fixture.date(2026, 6, 21, 12, 0, in: Fixture.reykjavikZone)) == .day)
        let morning = try #require(times.goldenHour.morning)
        #expect(morning.start == times.solarNoon.addingTimeInterval(-43_200))
        #expect(close(morning.end, Fixture.date(2026, 6, 21, 4, 52, 24, in: Fixture.reykjavikZone), within: 60))
        #expect(times.blueHour.isEmpty)
    }

    @Test("Events are in order and the next one is found")
    func events() throws {
        let times = try Fixture.istanbulDay()
        let kinds = times.events().map(\.kind)
        #expect(kinds == SunEvent.Kind.allCases)
        #expect(times.nextEvent(after: Fixture.date(2026, 10, 18, 12, 0))?.kind == .solarNoon)
        let next = try #require(times.nextEvent(after: Fixture.date(2026, 10, 18, 13, 0)))
        #expect(next.kind == .goldenHourEveningStart)
        #expect(close(next.date, Fixture.date(2026, 10, 18, 17, 42, 2)))
        #expect(abs(next.countdown(from: Fixture.date(2026, 10, 18, 13, 0)) - 16_922) < 30)
        #expect(times.nextEvent(after: Fixture.date(2026, 10, 18, 21, 0)) == nil)
    }

    @Test("The countdown carries over to tomorrow")
    func nextEventTomorrow() throws {
        let today = try Fixture.istanbulDay()
        let tomorrow = try Fixture.sunTimes("istanbul-2026-10-19", coordinate: Fixture.istanbul)
        let next = try #require([today, tomorrow].nextEvent(after: Fixture.date(2026, 10, 18, 21, 0)))
        #expect(next.kind == .astronomicalDawn)
        #expect(next.date == tomorrow.astronomicalTwilightBegin)
        #expect([today, tomorrow].day(containing: Fixture.date(2026, 10, 19, 3, 0))?.day == tomorrow.day)
    }

    @Test("Timeline fractions and segments")
    func timeline() throws {
        let times = try Fixture.istanbulDay()
        let timeline = times.timeline
        #expect(timeline.fraction(at: Fixture.date(2026, 10, 18, 12, 0)) == 0.5)
        #expect(timeline.fraction(at: Fixture.date(2026, 10, 18, 6, 0)) == 0.25)
        #expect(timeline.fraction(at: Fixture.date(2026, 10, 17, 12, 0)) == 0)
        #expect(timeline.fraction(at: Fixture.date(2026, 10, 19, 12, 0)) == 1)
        #expect(timeline.date(at: 0.75) == Fixture.date(2026, 10, 18, 18, 0))

        let segments = timeline.segments
        #expect(segments.first?.start == 0)
        #expect(segments.last?.end == 1)
        #expect(segments.first?.phase == .night)
        #expect(segments.last?.phase == .night)
        for (left, right) in zip(segments, segments.dropFirst()) {
            #expect(left.end == right.start)
            #expect(left.phase != right.phase)
        }
        let phases = segments.map(\.phase)
        let expected: [SunPhase] = [
            .night, .astronomicalTwilight, .nauticalTwilight, .civilTwilight, .goldenHour, .day,
            .goldenHour, .civilTwilight, .nauticalTwilight, .astronomicalTwilight, .night,
        ]
        #expect(phases == expected)
        #expect(timeline.phase(at: 0.5) == .day)
    }

    @Test("Sun progress and altitude")
    func progress() throws {
        let times = try Fixture.istanbulDay()
        let sunrise = try #require(times.sunrise)
        #expect(times.sunProgress(at: sunrise) == 0)
        #expect(times.sunProgress(at: Fixture.date(2026, 10, 18, 3, 0)) == nil)
        let noonProgress = try #require(times.sunProgress(at: times.solarNoon))
        #expect(abs(noonProgress - 0.5) < 0.01)
        // 90° - |41.01° - (-9.69°)| ≈ 39.3° at noon.
        #expect(abs(times.altitude(at: times.solarNoon) - 39.3) < 0.2)
        #expect(abs(times.altitude(at: sunrise) - SolarGeometry.horizonAltitude) < 0.3)
        #expect(times.isMorning(at: Fixture.date(2026, 10, 18, 9, 0)))
    }

    @Test("Declination at the solstices")
    func declination() {
        #expect(abs(SolarGeometry.declination(at: Fixture.date(2026, 6, 21, 12, 0)) - 23.44) < 0.05)
        #expect(abs(SolarGeometry.declination(at: Fixture.date(2026, 12, 21, 12, 0)) + 23.44) < 0.05)
    }

    @Test("Formatting")
    func formatting() {
        #expect(SunFormat.duration(39_644) == "11h 01m")
        #expect(SunFormat.duration(0) == "0h 00m")
        #expect(SunFormat.countdown(8_040) == "2h 14m")
        #expect(SunFormat.countdown(30) == "under 1m")
        #expect(SunFormat.change(161) == "+2m 41s")
        #expect(SunFormat.change(-65) == "−1m 05s")
        #expect(SunFormat.time(nil, in: Fixture.istanbulZone) == "—")
        let time = SunFormat.time(Fixture.date(2026, 10, 18, 7, 18), in: Fixture.istanbulZone, locale: Locale(identifier: "en_GB"))
        #expect(time == "07:18")
    }
}
