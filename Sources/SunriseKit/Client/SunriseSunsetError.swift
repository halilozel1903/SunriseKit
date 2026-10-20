import Foundation

/// Errors thrown by ``SunriseSunsetClient``.
public enum SunriseSunsetError: Error, Equatable, Sendable, LocalizedError {
    /// The API answered with a status other than `OK`, such as `INVALID_DATE`.
    case status(SunriseSunsetStatus)
    /// The request was not sent because a parameter is invalid (checked before any network access).
    case invalidRequest(String)
    /// An unsuccessful HTTP status without the API's JSON body.
    case http(statusCode: Int)
    /// The response was not JSON of the expected shape.
    case decoding(String)
    /// The request could not be completed (offline, timed out, cancelled…).
    case transport(URLError)
    /// The response was not an HTTP response.
    case invalidResponse

    /// Whether sending the same request again may succeed.
    public var isRetryable: Bool {
        switch self {
        case let .status(status): status.isRetryable
        case let .http(statusCode): statusCode == 429 || statusCode >= 500
        case .transport: true
        default: false
        }
    }

    public var errorDescription: String? {
        switch self {
        case let .status(status): status.explanation
        case let .invalidRequest(reason): reason
        case let .http(statusCode): "sunrise-sunset.org answered with HTTP status \(statusCode)."
        case .decoding: "sunrise-sunset.org sent data that could not be read."
        case let .transport(error): error.localizedDescription
        case .invalidResponse: "sunrise-sunset.org sent an invalid response."
        }
    }
}
