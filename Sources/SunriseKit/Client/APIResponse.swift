import Foundation

/// The JSON envelope: `{"results": {...}, "status": "OK", "tzid": "Europe/Istanbul"}`.
/// On errors `results` is an empty string, so it is only decoded when the status says there are results.
struct APIEnvelope: Decodable {
    let status: SunriseSunsetStatus
    let tzid: String?
    private let decodedResults: Result<APIResults, any Error>

    enum CodingKeys: String, CodingKey {
        case results
        case status
        case tzid
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = SunriseSunsetStatus(rawValue: try container.decode(String.self, forKey: .status))
        tzid = try container.decodeIfPresent(String.self, forKey: .tzid)
        do {
            decodedResults = .success(try container.decode(APIResults.self, forKey: .results))
        } catch {
            decodedResults = .failure(error)
        }
    }

    /// The results, or the error that kept them from decoding (on errors `results` is `""`).
    func results() throws -> APIResults {
        try decodedResults.get()
    }
}

/// `results` with `formatted=0`: ISO 8601 strings and `day_length` in seconds.
struct APIResults: Decodable {
    let sunrise: String
    let sunset: String
    let solarNoon: String
    let dayLength: Double
    let civilTwilightBegin: String
    let civilTwilightEnd: String
    let nauticalTwilightBegin: String
    let nauticalTwilightEnd: String
    let astronomicalTwilightBegin: String
    let astronomicalTwilightEnd: String

    enum CodingKeys: String, CodingKey {
        case sunrise
        case sunset
        case solarNoon = "solar_noon"
        case dayLength = "day_length"
        case civilTwilightBegin = "civil_twilight_begin"
        case civilTwilightEnd = "civil_twilight_end"
        case nauticalTwilightBegin = "nautical_twilight_begin"
        case nauticalTwilightEnd = "nautical_twilight_end"
        case astronomicalTwilightBegin = "astronomical_twilight_begin"
        case astronomicalTwilightEnd = "astronomical_twilight_end"
    }

    /// Typed times. `day` is the requested day, or `nil` to take it from the solar noon.
    func sunTimes(day: CalendarDay?, coordinate: Coordinate, timeZone: TimeZone) throws -> SunTimes {
        func event(_ value: String, _ name: String) throws -> Date? {
            guard let date = SunriseSunsetTime.parse(value) else {
                throw SunriseSunsetError.decoding("\(name) is not an ISO 8601 time: \(value)")
            }
            return SunriseSunsetTime.isPlaceholder(date) ? nil : date
        }
        guard let noon = try event(solarNoon, "solar_noon") else {
            throw SunriseSunsetError.decoding("solar_noon is missing.")
        }
        return SunTimes(
            day: day ?? CalendarDay(noon, in: timeZone),
            coordinate: coordinate,
            timeZone: timeZone,
            sunrise: try event(sunrise, "sunrise"),
            sunset: try event(sunset, "sunset"),
            solarNoon: noon,
            dayLength: dayLength,
            civilTwilightBegin: try event(civilTwilightBegin, "civil_twilight_begin"),
            civilTwilightEnd: try event(civilTwilightEnd, "civil_twilight_end"),
            nauticalTwilightBegin: try event(nauticalTwilightBegin, "nautical_twilight_begin"),
            nauticalTwilightEnd: try event(nauticalTwilightEnd, "nautical_twilight_end"),
            astronomicalTwilightBegin: try event(astronomicalTwilightBegin, "astronomical_twilight_begin"),
            astronomicalTwilightEnd: try event(astronomicalTwilightEnd, "astronomical_twilight_end")
        )
    }
}
