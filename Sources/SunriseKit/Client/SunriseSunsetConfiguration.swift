import Foundation

/// Where the client sends requests and with which `URLSession`.
public struct SunriseSunsetConfiguration: Sendable {
    /// The JSON endpoint, `https://api.sunrise-sunset.org/json` by default.
    public var endpoint: URL
    public var session: URLSession
    /// How many requests a date range sends at the same time.
    public var maximumConcurrentRequests: Int

    public static let defaultEndpoint = URL(string: "https://api.sunrise-sunset.org/json")!

    public init(
        endpoint: URL = SunriseSunsetConfiguration.defaultEndpoint,
        session: URLSession = .shared,
        maximumConcurrentRequests: Int = 4
    ) {
        self.endpoint = endpoint
        self.session = session
        self.maximumConcurrentRequests = max(1, maximumConcurrentRequests)
    }
}
