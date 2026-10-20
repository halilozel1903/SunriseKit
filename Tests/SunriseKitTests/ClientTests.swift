import Foundation
import Testing
@testable import SunriseKit

@Suite("Client")
struct ClientTests {
    @Test("Sends lat, lng, date, formatted=0 and tzid to /json")
    func query() async throws {
        let stub = StubbedClient(fixture: "istanbul-2026-10-18")
        let times = try await stub.client.sunTimes(
            for: Fixture.istanbul,
            date: .day(CalendarDay(year: 2026, month: 10, day: 18)),
            timeZone: Fixture.istanbulZone
        )
        let query = try #require(stub.queries().first)
        #expect(stub.requests.first?.url?.path == "/json")
        #expect(query["lat"] == "41.0082")
        #expect(query["lng"] == "28.9784")
        #expect(query["date"] == "2026-10-18")
        #expect(query["formatted"] == "0")
        #expect(query["tzid"] == "Europe/Istanbul")
        #expect(times.day == CalendarDay(year: 2026, month: 10, day: 18))
        #expect(times.timeZone.identifier == "Europe/Istanbul")
        #expect(times.sunrise == Fixture.date(2026, 10, 18, 7, 18, 52))
    }

    @Test("today and tomorrow are sent as words, and the day comes from the solar noon")
    func relativeDates() async throws {
        let stub = StubbedClient(fixture: "istanbul-2026-10-18")
        let times = try await stub.client.sunTimes(latitude: 41.0082, longitude: 28.9784, timeZone: Fixture.istanbulZone)
        _ = try await stub.client.sunTimes(latitude: 41.0082, longitude: 28.9784, date: .tomorrow)
        let queries = stub.queries()
        #expect(queries.count == 2)
        #expect(queries.first?["date"] == "today")
        #expect(queries.last?["date"] == "tomorrow")
        #expect(queries.last?["tzid"] == nil)
        #expect(times.day == CalendarDay(year: 2026, month: 10, day: 18))
    }

    @Test("Error statuses throw", arguments: [
        ("error-invalid-request", SunriseSunsetStatus.invalidRequest),
        ("error-invalid-date", SunriseSunsetStatus.invalidDate),
        ("error-unknown", SunriseSunsetStatus.unknownError),
        ("invalid-tzid", SunriseSunsetStatus.invalidTimeZone),
    ])
    func errorStatuses(fixture: String, status: SunriseSunsetStatus) async throws {
        // The API sends INVALID_REQUEST and INVALID_DATE with HTTP 400; the body still decides the error.
        let stub = StubbedClient(fixture: fixture, status: status == .invalidTimeZone ? 200 : 400)
        await #expect(throws: SunriseSunsetError.status(status)) {
            try await stub.client.sunTimes(latitude: 41.0082, longitude: 28.9784, timeZone: Fixture.istanbulZone)
        }
    }

    @Test("UNKNOWN_ERROR is retryable, INVALID_DATE is not")
    func retryable() {
        #expect(SunriseSunsetError.status(.unknownError).isRetryable)
        #expect(!SunriseSunsetError.status(.invalidDate).isRetryable)
        #expect(SunriseSunsetError.http(statusCode: 503).isRetryable)
        #expect(SunriseSunsetStatus(rawValue: "SOMETHING_NEW") == .other("SOMETHING_NEW"))
        #expect(SunriseSunsetStatus(rawValue: "INVALID_TZID").rawValue == "INVALID_TZID")
    }

    @Test("INVALID_TZID can fall back to UTC times")
    func utcFallback() async throws {
        let stub = StubbedClient(fixture: "invalid-tzid")
        let request = SunTimesRequest(
            coordinate: Fixture.istanbul,
            date: .day(CalendarDay(year: 2026, month: 10, day: 18)),
            timeZone: TimeZone(identifier: "Asia/Tokyo"),
            allowsUTCFallback: true
        )
        let times = try await stub.client.sunTimes(request)
        #expect(times.usedUTCFallback)
        #expect(times.timeZone.secondsFromGMT() == 0)
        // The same instant as the Istanbul fixture, written in UTC.
        #expect(times.sunrise == Fixture.date(2026, 10, 18, 7, 18, 52))
    }

    @Test("Out-of-range coordinates and dates are rejected before sending")
    func validation() async throws {
        let stub = StubbedClient(fixture: "istanbul-2026-10-18")
        await #expect(throws: SunriseSunsetError.self) {
            try await stub.client.sunTimes(latitude: 91, longitude: 0)
        }
        await #expect(throws: SunriseSunsetError.self) {
            try await stub.client.sunTimes(latitude: 0, longitude: -181)
        }
        await #expect(throws: SunriseSunsetError.self) {
            try await stub.client.sunTimes(for: Fixture.istanbul, date: .day(CalendarDay(year: 2026, month: 2, day: 30)))
        }
        await #expect(throws: SunriseSunsetError.self) {
            try await stub.client.sunTimes(latitude: .nan, longitude: 0)
        }
        #expect(stub.requests.isEmpty)
    }

    @Test("An HTTP error without JSON is an http error")
    func httpError() async throws {
        let stub = StubbedClient { _ in StubResponse.text("<html>Bad gateway</html>", status: 502) }
        await #expect(throws: SunriseSunsetError.http(statusCode: 502)) {
            try await stub.client.sunTimes(latitude: 41, longitude: 29)
        }
    }

    @Test("A 200 that is not the API's JSON is a decoding error")
    func decodingError() async throws {
        let stub = StubbedClient { _ in StubResponse.text(#"{"hello": "world"}"#, status: 200) }
        await #expect(throws: SunriseSunsetError.self) {
            try await stub.client.sunTimes(latitude: 41, longitude: 29)
        }
    }

    @Test("A transport failure is a transport error")
    func transportError() async throws {
        let stub = StubbedClient { _ in throw URLError(.badServerResponse) }
        await #expect(throws: SunriseSunsetError.self) {
            try await stub.client.sunTimes(latitude: 41, longitude: 29)
        }
    }

    @Test("A range sends one request per day and keeps the days in order")
    func range() async throws {
        let stub = StubbedClient { request in
            let date = queryValue("date", in: request) ?? ""
            return try StubResponse.json(date == "2026-10-19" ? "istanbul-2026-10-19" : "istanbul-2026-10-18")
        }
        let first = CalendarDay(year: 2026, month: 10, day: 17)
        let days = try await stub.client.sunTimes(
            for: Fixture.istanbul,
            startingOn: first,
            count: 3,
            timeZone: Fixture.istanbulZone
        )
        #expect(days.map(\.day.description) == ["2026-10-17", "2026-10-18", "2026-10-19"])
        #expect(Set(stub.queries().compactMap { $0["date"] }) == ["2026-10-17", "2026-10-18", "2026-10-19"])
        #expect(days[2].sunrise == Fixture.date(2026, 10, 19, 7, 19, 58))
    }

    @Test("A range longer than 31 days or running backwards is rejected")
    func rangeLimits() async throws {
        let stub = StubbedClient(fixture: "istanbul-2026-10-18")
        let first = CalendarDay(year: 2026, month: 1, day: 1)
        await #expect(throws: SunriseSunsetError.self) {
            try await stub.client.sunTimes(for: Fixture.istanbul, from: first, through: first.adding(days: 31))
        }
        await #expect(throws: SunriseSunsetError.self) {
            try await stub.client.sunTimes(for: Fixture.istanbul, from: first, through: first.adding(days: -1))
        }
        #expect(stub.requests.isEmpty)
    }
}
