import Foundation

/// Reads the ISO 8601 times the API sends with `formatted=0`, such as `2026-10-18T07:18:52+03:00`.
public enum SunriseSunsetTime {
    /// Times before this are the API's marker for an event that does not happen that day. The API answers
    /// `1970-01-01T00:00:01+00:00` (in the requested time zone) for a sunrise during polar night, a sunset
    /// during midnight sun, or a twilight that never ends in a white night.
    public static let placeholderLimit = Date(timeIntervalSince1970: 2 * 86_400)

    /// Whether `date` is the "does not happen" marker.
    public static func isPlaceholder(_ date: Date) -> Bool {
        date < placeholderLimit
    }

    /// Parses `YYYY-MM-DDTHH:MM:SS` with optional fractional seconds and a `Z`, `±HH:MM` or `±HHMM` offset.
    /// Returns `nil` for anything else.
    public static func parse(_ string: String) -> Date? {
        let characters = Array(string.utf8)
        guard characters.count >= 19,
              characters[4] == UInt8(ascii: "-"), characters[7] == UInt8(ascii: "-"),
              characters[10] == UInt8(ascii: "T") || characters[10] == UInt8(ascii: " "),
              characters[13] == UInt8(ascii: ":"), characters[16] == UInt8(ascii: ":"),
              let year = number(characters, 0, 4), let month = number(characters, 5, 2),
              let day = number(characters, 8, 2), let hour = number(characters, 11, 2),
              let minute = number(characters, 14, 2), let second = number(characters, 17, 2),
              (1...12).contains(month), (1...31).contains(day), hour < 24, minute < 60, second < 61
        else { return nil }

        var index = 19
        var fraction = 0.0
        if index < characters.count, characters[index] == UInt8(ascii: ".") {
            index += 1
            var scale = 0.1
            let start = index
            while index < characters.count, let digit = digit(characters[index]) {
                fraction += Double(digit) * scale
                scale /= 10
                index += 1
            }
            guard index > start else { return nil }
        }

        var offset = 0
        if index < characters.count {
            let sign = characters[index]
            if sign == UInt8(ascii: "Z"), index + 1 == characters.count {
                offset = 0
            } else if sign == UInt8(ascii: "+") || sign == UInt8(ascii: "-") {
                let rest = Array(characters[(index + 1)...])
                let hours: Int?
                let minutes: Int?
                if rest.count == 5, rest[2] == UInt8(ascii: ":") {
                    hours = number(rest, 0, 2)
                    minutes = number(rest, 3, 2)
                } else if rest.count == 4 {
                    hours = number(rest, 0, 2)
                    minutes = number(rest, 2, 2)
                } else if rest.count == 2 {
                    hours = number(rest, 0, 2)
                    minutes = 0
                } else {
                    return nil
                }
                guard let hours, let minutes, hours < 24, minutes < 60 else { return nil }
                offset = (hours * 3600 + minutes * 60) * (sign == UInt8(ascii: "-") ? -1 : 1)
            } else {
                return nil
            }
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let base = calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute, second: second
        )) else { return nil }
        return base.addingTimeInterval(fraction - Double(offset))
    }

    private static func digit(_ character: UInt8) -> Int? {
        (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(character) ? Int(character - UInt8(ascii: "0")) : nil
    }

    private static func number(_ characters: [UInt8], _ start: Int, _ length: Int) -> Int? {
        guard start + length <= characters.count else { return nil }
        var value = 0
        for index in start..<(start + length) {
            guard let digit = digit(characters[index]) else { return nil }
            value = value * 10 + digit
        }
        return value
    }
}
