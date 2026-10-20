import Foundation

/// The `status` field of every response.
public enum SunriseSunsetStatus: Hashable, Sendable, CustomStringConvertible {
    /// `OK`: no errors.
    case ok
    /// `INVALID_REQUEST`: `lat` or `lng` is missing, invalid or out of range.
    case invalidRequest
    /// `INVALID_DATE`: `date` is missing or could not be read.
    case invalidDate
    /// `UNKNOWN_ERROR`: the server failed; trying again may work.
    case unknownError
    /// `INVALID_TZID`: `tzid` is not a known time zone; the times are in UTC.
    case invalidTimeZone
    /// A status this version of SunriseKit does not know.
    case other(String)

    public init(rawValue: String) {
        switch rawValue {
        case "OK": self = .ok
        case "INVALID_REQUEST": self = .invalidRequest
        case "INVALID_DATE": self = .invalidDate
        case "UNKNOWN_ERROR": self = .unknownError
        case "INVALID_TZID": self = .invalidTimeZone
        default: self = .other(rawValue)
        }
    }

    /// The value as the API spells it.
    public var rawValue: String {
        switch self {
        case .ok: "OK"
        case .invalidRequest: "INVALID_REQUEST"
        case .invalidDate: "INVALID_DATE"
        case .unknownError: "UNKNOWN_ERROR"
        case .invalidTimeZone: "INVALID_TZID"
        case let .other(value): value
        }
    }

    /// Whether sending the same request again may succeed.
    public var isRetryable: Bool {
        self == .unknownError
    }

    /// A sentence for people.
    public var explanation: String {
        switch self {
        case .ok: "The request succeeded."
        case .invalidRequest: "The latitude or longitude is missing or invalid."
        case .invalidDate: "The date is missing or invalid."
        case .unknownError: "The sunrise-sunset.org server could not process the request. Try again."
        case .invalidTimeZone: "The time zone is not valid, so the times are in UTC."
        case let .other(value): "The API answered with the status \(value)."
        }
    }

    public var description: String {
        rawValue
    }
}
