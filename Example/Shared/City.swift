import Foundation
import SunriseKit

/// A place to show the sun for: a real city with its real coordinates and time zone, or the device's location.
struct City: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let country: String
    let coordinate: Coordinate
    let timeZone: TimeZone

    /// The fixed list both apps show. Coordinates are the city centres.
    static let all: [City] = [
        City(id: "istanbul", name: "Istanbul", country: "Türkiye",
             coordinate: Coordinate(latitude: 41.0082, longitude: 28.9784),
             timeZone: TimeZone(identifier: "Europe/Istanbul")!),
        City(id: "reykjavik", name: "Reykjavik", country: "Iceland",
             coordinate: Coordinate(latitude: 64.1466, longitude: -21.9426),
             timeZone: TimeZone(identifier: "Atlantic/Reykjavik")!),
        City(id: "tokyo", name: "Tokyo", country: "Japan",
             coordinate: Coordinate(latitude: 35.6762, longitude: 139.6503),
             timeZone: TimeZone(identifier: "Asia/Tokyo")!),
        City(id: "new-york", name: "New York", country: "United States",
             coordinate: Coordinate(latitude: 40.7128, longitude: -74.0060),
             timeZone: TimeZone(identifier: "America/New_York")!),
        City(id: "cape-town", name: "Cape Town", country: "South Africa",
             coordinate: Coordinate(latitude: -33.9249, longitude: 18.4241),
             timeZone: TimeZone(identifier: "Africa/Johannesburg")!),
        City(id: "tromso", name: "Tromsø", country: "Norway",
             coordinate: Coordinate(latitude: 69.6492, longitude: 18.9553),
             timeZone: TimeZone(identifier: "Europe/Oslo")!),
    ]

    static let istanbul = all[0]
    static let reykjavik = all[1]

    /// The device's location, in the device's time zone.
    static func current(latitude: Double, longitude: Double) -> City {
        City(id: "current", name: "My Location", country: "Current location",
             coordinate: Coordinate(latitude: latitude, longitude: longitude),
             timeZone: .current)
    }

    /// The local day it is now in this city.
    func today(_ now: Date = .now) -> CalendarDay {
        CalendarDay(now, in: timeZone)
    }

    /// The local time now, such as "14:05" or "2:05 PM".
    func localTime(_ now: Date) -> String {
        SunFormat.time(now, in: timeZone)
    }
}
