import Foundation

/// The day to ask for.
public enum SunDate: Hashable, Sendable {
    /// Today, in the request's time zone (in UTC when the request has none).
    case today
    /// Tomorrow, in the request's time zone.
    case tomorrow
    /// A specific day.
    case day(CalendarDay)

    /// The value of the `date` query parameter.
    public var queryValue: String {
        switch self {
        case .today: "today"
        case .tomorrow: "tomorrow"
        case let .day(day): day.description
        }
    }
}

/// One request to `GET /json`: a coordinate, a day and the time zone to express the times in.
public struct SunTimesRequest: Hashable, Sendable {
    public var coordinate: Coordinate
    public var date: SunDate
    /// Sent as `tzid`. Also decides which local day `today` and `tomorrow` mean. Without one, the API uses UTC.
    public var timeZone: TimeZone?
    /// The API answers an unknown `tzid` with the status `INVALID_TZID` and UTC times. By default the client
    /// throws ``SunriseSunsetError/status(_:)``; set this to `true` to accept the UTC times instead.
    public var allowsUTCFallback: Bool

    public init(
        coordinate: Coordinate,
        date: SunDate = .today,
        timeZone: TimeZone? = nil,
        allowsUTCFallback: Bool = false
    ) {
        self.coordinate = coordinate
        self.date = date
        self.timeZone = timeZone
        self.allowsUTCFallback = allowsUTCFallback
    }

    public init(
        latitude: Double,
        longitude: Double,
        date: SunDate = .today,
        timeZone: TimeZone? = nil,
        allowsUTCFallback: Bool = false
    ) {
        self.init(
            coordinate: Coordinate(latitude: latitude, longitude: longitude),
            date: date,
            timeZone: timeZone,
            allowsUTCFallback: allowsUTCFallback
        )
    }

    /// Throws ``SunriseSunsetError/invalidRequest(_:)`` for values the API would reject.
    public func validate() throws {
        guard coordinate.isValid else {
            throw SunriseSunsetError.invalidRequest(
                "The coordinate \(coordinate.latitude), \(coordinate.longitude) is out of range."
            )
        }
        if case let .day(day) = date, !day.isValid {
            throw SunriseSunsetError.invalidRequest("\(day) is not a valid date.")
        }
    }

    /// `lat`, `lng`, `date`, `formatted=0` (ISO 8601 times, day length in seconds) and `tzid`.
    public var queryItems: [URLQueryItem] {
        var items = [
            URLQueryItem(name: "lat", value: String(coordinate.latitude)),
            URLQueryItem(name: "lng", value: String(coordinate.longitude)),
            URLQueryItem(name: "date", value: date.queryValue),
            URLQueryItem(name: "formatted", value: "0"),
        ]
        if let timeZone {
            items.append(URLQueryItem(name: "tzid", value: timeZone.identifier))
        }
        return items
    }
}
