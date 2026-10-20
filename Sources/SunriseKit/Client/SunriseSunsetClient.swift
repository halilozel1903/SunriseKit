import Foundation

/// A client for the free [Sunrise Sunset API](https://sunrise-sunset.org/api) (`https://api.sunrise-sunset.org/json`).
///
/// ```swift
/// let sun = SunriseSunsetClient()
/// let today = try await sun.sunTimes(latitude: 41.0082, longitude: 28.9784,
///                                    timeZone: TimeZone(identifier: "Europe/Istanbul"))
/// print(today.sunrise, today.sunset, today.goldenHour.evening)
/// print(today.phase(at: .now).title)             // "Golden hour"
/// ```
///
/// Every request asks for `formatted=0`, so times arrive as ISO 8601 and the day length in seconds. The API needs
/// no key; credit sunrise-sunset.org wherever you show its data (see ``SunriseSunsetAttribution``).
/// One client can be shared by the whole app: it is `Sendable` and keeps no per-request state.
public final class SunriseSunsetClient: Sendable {
    /// A client with the default configuration.
    public static let shared = SunriseSunsetClient()

    /// The longest date range ``sunTimes(for:from:through:timeZone:)`` accepts.
    public static let maximumRangeDays = 31

    public let configuration: SunriseSunsetConfiguration

    public init(configuration: SunriseSunsetConfiguration = SunriseSunsetConfiguration()) {
        self.configuration = configuration
    }

    /// A client using `session`, with the default settings otherwise.
    public convenience init(session: URLSession) {
        self.init(configuration: SunriseSunsetConfiguration(session: session))
    }

    // MARK: - One day

    /// The sun times of one day.
    public func sunTimes(_ request: SunTimesRequest) async throws -> SunTimes {
        try request.validate()
        let envelope = try await send(request)
        switch envelope.status {
        case .ok:
            break
        case .invalidTimeZone where request.allowsUTCFallback:
            break
        default:
            throw SunriseSunsetError.status(envelope.status)
        }
        let utc = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        let timeZone: TimeZone
        if envelope.status == .invalidTimeZone {
            timeZone = utc
        } else {
            timeZone = envelope.tzid.flatMap(TimeZone.init(identifier:)) ?? request.timeZone ?? utc
        }
        let day: CalendarDay? = if case let .day(day) = request.date { day } else { nil }
        let results: APIResults
        do {
            results = try envelope.results()
        } catch {
            throw SunriseSunsetError.decoding(String(describing: error))
        }
        var times = try results.sunTimes(day: day, coordinate: request.coordinate, timeZone: timeZone)
        times.usedUTCFallback = envelope.status == .invalidTimeZone
        return times
    }

    /// The sun times of one day at a coordinate. Pass the place's time zone so `today` means its local day and the
    /// times come back in local time.
    public func sunTimes(
        latitude: Double,
        longitude: Double,
        date: SunDate = .today,
        timeZone: TimeZone? = nil
    ) async throws -> SunTimes {
        try await sunTimes(SunTimesRequest(latitude: latitude, longitude: longitude, date: date, timeZone: timeZone))
    }

    /// The sun times of one day at a coordinate.
    public func sunTimes(
        for coordinate: Coordinate,
        date: SunDate = .today,
        timeZone: TimeZone? = nil
    ) async throws -> SunTimes {
        try await sunTimes(SunTimesRequest(coordinate: coordinate, date: date, timeZone: timeZone))
    }

    // MARK: - A range of days

    /// The sun times of every day from `firstDay` through `lastDay`, in order, at most
    /// ``maximumRangeDays`` days.
    ///
    /// Version 1 of the API (`/json`) has no `date_start`/`date_end`; this sends one request per day, a few at a
    /// time (``SunriseSunsetConfiguration/maximumConcurrentRequests``), and fails when any day fails.
    public func sunTimes(
        for coordinate: Coordinate,
        from firstDay: CalendarDay,
        through lastDay: CalendarDay,
        timeZone: TimeZone? = nil
    ) async throws -> [SunTimes] {
        guard firstDay.isValid, lastDay.isValid else {
            throw SunriseSunsetError.invalidRequest("\(firstDay) or \(lastDay) is not a valid date.")
        }
        let days = firstDay.days(through: lastDay)
        guard !days.isEmpty else {
            throw SunriseSunsetError.invalidRequest("\(lastDay) is before \(firstDay).")
        }
        guard days.count <= Self.maximumRangeDays else {
            throw SunriseSunsetError.invalidRequest(
                "A range can have at most \(Self.maximumRangeDays) days, not \(days.count)."
            )
        }
        let requests = days.map { SunTimesRequest(coordinate: coordinate, date: .day($0), timeZone: timeZone) }
        for request in requests {
            try request.validate()
        }

        return try await withThrowingTaskGroup(of: (Int, SunTimes).self) { group in
            var results = [SunTimes?](repeating: nil, count: requests.count)
            var pending = requests.enumerated().makeIterator()
            for _ in 0..<min(configuration.maximumConcurrentRequests, requests.count) {
                if let item = pending.next() {
                    let index = item.offset
                    let request = item.element
                    group.addTask {
                        let times = try await self.sunTimes(request)
                        return (index, times)
                    }
                }
            }
            while let finished = try await group.next() {
                results[finished.0] = finished.1
                if let item = pending.next() {
                    let nextIndex = item.offset
                    let request = item.element
                    group.addTask {
                        let times = try await self.sunTimes(request)
                        return (nextIndex, times)
                    }
                }
            }
            return results.compactMap { $0 }
        }
    }

    /// `count` days starting with `firstDay`.
    public func sunTimes(
        for coordinate: Coordinate,
        startingOn firstDay: CalendarDay,
        count: Int,
        timeZone: TimeZone? = nil
    ) async throws -> [SunTimes] {
        guard count >= 1 else {
            throw SunriseSunsetError.invalidRequest("count must be at least 1, not \(count).")
        }
        return try await sunTimes(
            for: coordinate,
            from: firstDay,
            through: firstDay.adding(days: count - 1),
            timeZone: timeZone
        )
    }

    // MARK: - Transport

    func url(for request: SunTimesRequest) throws -> URL {
        guard var components = URLComponents(url: configuration.endpoint, resolvingAgainstBaseURL: false) else {
            throw SunriseSunsetError.invalidRequest("The endpoint \(configuration.endpoint) is not a valid URL.")
        }
        components.queryItems = (components.queryItems ?? []) + request.queryItems
        guard let url = components.url else {
            throw SunriseSunsetError.invalidRequest("The request could not be turned into a URL.")
        }
        return url
    }

    private func send(_ request: SunTimesRequest) async throws -> APIEnvelope {
        var urlRequest = URLRequest(url: try url(for: request))
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await configuration.session.data(for: urlRequest)
        } catch let error as URLError {
            throw SunriseSunsetError.transport(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw SunriseSunsetError.invalidResponse
        }
        // Errors such as INVALID_REQUEST come with HTTP 400 and the usual JSON body, so read the body first.
        do {
            return try JSONDecoder().decode(APIEnvelope.self, from: data)
        } catch {
            if !(200..<300).contains(http.statusCode) {
                throw SunriseSunsetError.http(statusCode: http.statusCode)
            }
            throw SunriseSunsetError.decoding(String(describing: error))
        }
    }
}
