import Foundation

/// A point on Earth in decimal degrees.
public struct Coordinate: Hashable, Sendable, Codable {
    /// Degrees north of the equator, -90 to 90.
    public var latitude: Double
    /// Degrees east of Greenwich, -180 to 180.
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Whether both values are finite and in range. The client checks this before sending a request.
    public var isValid: Bool {
        latitude.isFinite && longitude.isFinite
            && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}
