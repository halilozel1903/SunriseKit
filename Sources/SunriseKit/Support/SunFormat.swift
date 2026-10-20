import Foundation

/// Text for times and durations.
public enum SunFormat {
    /// A time of day in `timeZone`, such as "7:18 AM" or "07:18" depending on the locale. "—" for `nil`.
    public static func time(_ date: Date?, in timeZone: TimeZone, locale: Locale = .autoupdatingCurrent) -> String {
        guard let date else { return "—" }
        var style = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone)
        style.calendar = Calendar(identifier: .gregorian)
        return date.formatted(style)
    }

    /// A short weekday and day, such as "Sun 18".
    public static func weekday(_ day: CalendarDay, in timeZone: TimeZone, locale: Locale = .autoupdatingCurrent) -> String {
        let style = Date.FormatStyle(locale: locale, timeZone: timeZone).weekday(.abbreviated).day()
        return day.startDate(in: timeZone).addingTimeInterval(43_200).formatted(style)
    }

    /// Hours and minutes, such as "11h 01m", rounded to the minute.
    public static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((max(0, seconds) / 60).rounded())
        let hours = minutes / 60
        let rest = minutes % 60
        return "\(hours)h " + (rest < 10 ? "0" : "") + "\(rest)m"
    }

    /// A day length change, such as "+2m 41s" or "−1m 05s".
    public static func change(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let sign = total < 0 ? "−" : "+"
        let magnitude = abs(total)
        let minutes = magnitude / 60
        let rest = magnitude % 60
        return sign + "\(minutes)m " + (rest < 10 ? "0" : "") + "\(rest)s"
    }

    /// A countdown, such as "2h 14m", "14m" or "under 1m".
    public static func countdown(_ seconds: TimeInterval) -> String {
        guard seconds >= 60 else { return "under 1m" }
        let minutes = Int(seconds / 60)
        let hours = minutes / 60
        let rest = minutes % 60
        return hours > 0 ? "\(hours)h \(rest)m" : "\(rest)m"
    }
}
