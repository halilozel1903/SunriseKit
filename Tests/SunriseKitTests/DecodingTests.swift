import Foundation
import Testing
@testable import SunriseKit

@Suite("Decoding")
struct DecodingTests {
    @Test("Every field of a normal day")
    func istanbul() throws {
        let times = try Fixture.istanbulDay()
        #expect(times.day == CalendarDay(year: 2026, month: 10, day: 18))
        #expect(times.sunStatus == .normal)
        #expect(times.sunrise == Fixture.date(2026, 10, 18, 7, 18, 52))
        #expect(times.sunset == Fixture.date(2026, 10, 18, 18, 19, 36))
        #expect(times.solarNoon == Fixture.date(2026, 10, 18, 12, 49, 14))
        #expect(times.dayLength == 39_644)
        #expect(times.civilTwilightBegin == Fixture.date(2026, 10, 18, 6, 51, 3))
        #expect(times.civilTwilightEnd == Fixture.date(2026, 10, 18, 18, 47, 24))
        #expect(times.nauticalTwilightBegin == Fixture.date(2026, 10, 18, 6, 19, 7))
        #expect(times.nauticalTwilightEnd == Fixture.date(2026, 10, 18, 19, 19, 21))
        #expect(times.astronomicalTwilightBegin == Fixture.date(2026, 10, 18, 5, 47, 18))
        #expect(times.astronomicalTwilightEnd == Fixture.date(2026, 10, 18, 19, 51, 10))
        #expect(!times.usedUTCFallback)
    }

    @Test("A white night: twilights that never end are nil, the sunset is after midnight")
    func whiteNight() throws {
        let times = try Fixture.sunTimes("reykjavik-2026-06-21", coordinate: Fixture.reykjavik, timeZone: Fixture.reykjavikZone)
        #expect(times.sunStatus == .normal)
        #expect(times.civilTwilightBegin == nil)
        #expect(times.civilTwilightEnd == nil)
        #expect(times.nauticalTwilightEnd == nil)
        #expect(times.astronomicalTwilightBegin == nil)
        #expect(times.sunset == Fixture.date(2026, 6, 22, 0, 3, 58, in: Fixture.reykjavikZone))
        #expect(times.dayLength == 76_124)
    }

    @Test("Midnight sun: the 1970 markers become nil, 24 hours of daylight")
    func midnightSun() throws {
        let times = try Fixture.sunTimes("longyearbyen-2026-06-21", coordinate: Fixture.longyearbyen, timeZone: Fixture.longyearbyenZone)
        #expect(times.sunStatus == .midnightSun)
        #expect(times.sunStatus.isPolar)
        #expect(times.sunrise == nil)
        #expect(times.sunset == nil)
        #expect(times.astronomicalTwilightEnd == nil)
        #expect(times.dayLength == 86_400)
        #expect(times.solarNoon == Fixture.date(2026, 6, 21, 12, 59, 18, in: Fixture.longyearbyenZone))
    }

    @Test("Polar night with nautical twilight at noon")
    func polarNight() throws {
        let times = try Fixture.sunTimes("longyearbyen-2026-12-21", coordinate: Fixture.longyearbyen, timeZone: Fixture.longyearbyenZone)
        #expect(times.sunStatus == .polarNight)
        #expect(times.dayLength == 0)
        #expect(times.sunrise == nil)
        #expect(times.civilTwilightBegin == nil)
        #expect(times.nauticalTwilightBegin == Fixture.date(2026, 12, 21, 10, 58, 21, in: Fixture.longyearbyenZone))
        #expect(times.daylight == nil)
    }

    @Test("All markers in December near the pole: polar night, not midnight sun")
    func northPole() throws {
        let times = try Fixture.sunTimes("north-pole-2026-12-21", coordinate: Fixture.northPole, timeZone: TimeZone(identifier: "UTC")!)
        #expect(times.sunStatus == .polarNight)
        #expect(times.dayLength == 0)
        #expect(times.events().map(\.kind) == [.solarNoon])
    }

    @Test("ISO 8601 times with offsets, Z and fractions")
    func parsing() throws {
        let utc = try #require(SunriseSunsetTime.parse("2026-10-18T04:18:52+00:00"))
        #expect(SunriseSunsetTime.parse("2026-10-18T07:18:52+03:00") == utc)
        #expect(SunriseSunsetTime.parse("2026-10-18T04:18:52Z") == utc)
        #expect(SunriseSunsetTime.parse("2026-10-17T23:18:52-05:00") == utc)
        #expect(SunriseSunsetTime.parse("2026-10-18T07:18:52+0300") == utc)
        #expect(SunriseSunsetTime.parse("2026-10-18T04:18:52") == utc)
        let fractional = try #require(SunriseSunsetTime.parse("2026-10-18T04:18:52.5Z"))
        #expect(fractional.timeIntervalSince(utc) == 0.5)
        #expect(SunriseSunsetTime.parse("7:27:02 AM") == nil)
        #expect(SunriseSunsetTime.parse("2026-13-18T04:18:52Z") == nil)
        #expect(SunriseSunsetTime.parse("2026-10-18T04:18:52+3") == nil)
        #expect(SunriseSunsetTime.parse("") == nil)
    }

    @Test("The 1970 marker in any time zone is a placeholder")
    func placeholder() throws {
        let marker = try #require(SunriseSunsetTime.parse("1970-01-01T00:00:01+00:00"))
        let shifted = try #require(SunriseSunsetTime.parse("1970-01-01T01:00:01+01:00"))
        #expect(SunriseSunsetTime.isPlaceholder(marker))
        #expect(SunriseSunsetTime.isPlaceholder(shifted))
        #expect(!SunriseSunsetTime.isPlaceholder(Fixture.date(2026, 10, 18)))
    }

    @Test("A malformed time is a decoding error, not nil")
    func malformed() throws {
        let json = #"{"results":{"sunrise":"soon","sunset":"2026-10-18T18:19:36+03:00","solar_noon":"2026-10-18T12:49:14+03:00","day_length":1,"civil_twilight_begin":"2026-10-18T06:51:03+03:00","civil_twilight_end":"2026-10-18T18:47:24+03:00","nautical_twilight_begin":"2026-10-18T06:19:07+03:00","nautical_twilight_end":"2026-10-18T19:19:21+03:00","astronomical_twilight_begin":"2026-10-18T05:47:18+03:00","astronomical_twilight_end":"2026-10-18T19:51:10+03:00"},"status":"OK"}"#
        let envelope = try JSONDecoder().decode(APIEnvelope.self, from: Data(json.utf8))
        #expect(throws: SunriseSunsetError.self) {
            try envelope.results().sunTimes(day: nil, coordinate: Fixture.istanbul, timeZone: Fixture.istanbulZone)
        }
    }

    @Test("Error bodies have an empty results string")
    func errorBody() throws {
        let envelope = try JSONDecoder().decode(APIEnvelope.self, from: Fixture.data("error-invalid-date"))
        #expect(envelope.status == .invalidDate)
        #expect(throws: (any Error).self) {
            try envelope.results()
        }
    }

    @Test("Calendar days")
    func calendarDays() throws {
        let day = try #require(CalendarDay("2026-12-31"))
        #expect(day.adding(days: 1).description == "2027-01-01")
        #expect(day.adding(days: -365).description == "2025-12-31")
        #expect(CalendarDay("2026-02-29") == nil)
        #expect(CalendarDay("2028-02-29") != nil)
        #expect(CalendarDay("26-1-1") == nil)
        #expect(CalendarDay(year: 2026, month: 3, day: 5).description == "2026-03-05")
        #expect(day.days(through: day.adding(days: 2)).count == 3)
        #expect(CalendarDay(Fixture.date(2026, 10, 18, 1, 0), in: Fixture.istanbulZone).description == "2026-10-18")
        #expect(CalendarDay(Fixture.date(2026, 10, 18, 1, 0), in: TimeZone(identifier: "UTC")!).description == "2026-10-17")
    }

    @Test("SunTimes round-trips through Codable")
    func codable() throws {
        let times = try Fixture.istanbulDay()
        let data = try JSONEncoder().encode(times)
        let decoded = try JSONDecoder().decode(SunTimes.self, from: data)
        #expect(decoded == times)
    }
}
