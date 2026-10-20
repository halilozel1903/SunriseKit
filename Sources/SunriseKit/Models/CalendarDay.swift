import Foundation

/// A day on the calendar, without a time or a time zone, such as 2026-10-18.
public struct CalendarDay: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day `date` falls on in `timeZone`.
    public init(_ date: Date, in timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// Parses `YYYY-MM-DD`. Returns `nil` for anything else or for a day that does not exist.
    public init?(_ string: String) {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        self.init(year: year, month: month, day: day)
        guard isValid else { return nil }
    }

    /// `YYYY-MM-DD`, the format the API expects.
    public var description: String {
        Self.pad(year, 4) + "-" + Self.pad(month, 2) + "-" + Self.pad(day, 2)
    }

    /// Whether the day exists on the Gregorian calendar (no February 30).
    public var isValid: Bool {
        guard (1...12).contains(month), day >= 1 else { return false }
        let utc = Self.utcCalendar
        guard let first = utc.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = utc.range(of: .day, in: .month, for: first)
        else { return false }
        return range.contains(day)
    }

    /// The day `days` later (or earlier, for a negative number).
    public func adding(days: Int) -> CalendarDay {
        let utc = Self.utcCalendar
        guard let start = utc.date(from: DateComponents(year: year, month: month, day: day)),
              let moved = utc.date(byAdding: .day, value: days, to: start)
        else { return self }
        return CalendarDay(moved, in: utc.timeZone)
    }

    /// Every day from this one through `last`, both included. Empty when `last` is earlier.
    public func days(through last: CalendarDay) -> [CalendarDay] {
        var result: [CalendarDay] = []
        var current = self
        while current <= last {
            result.append(current)
            current = current.adding(days: 1)
        }
        return result
    }

    /// Local midnight at the start of this day in `timeZone`.
    public func startDate(in timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date(timeIntervalSince1970: 0)
    }

    public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func pad(_ value: Int, _ width: Int) -> String {
        let digits = String(abs(value))
        let padded = String(repeating: "0", count: max(0, width - digits.count)) + digits
        return value < 0 ? "-" + padded : padded
    }
}
