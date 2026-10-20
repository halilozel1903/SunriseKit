import Foundation
@testable import SunriseKit

/// JSON in `Fixtures/`, in the exact shape `GET /json?formatted=0` returns.
enum Fixture {
    struct Missing: Error {
        let name: String
    }

    static func data(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
            throw Missing(name: name)
        }
        return try Data(contentsOf: url)
    }

    static let istanbulZone = TimeZone(identifier: "Europe/Istanbul")!
    static let reykjavikZone = TimeZone(identifier: "Atlantic/Reykjavik")!
    static let longyearbyenZone = TimeZone(identifier: "Arctic/Longyearbyen")!

    static let istanbul = Coordinate(latitude: 41.0082, longitude: 28.9784)
    static let reykjavik = Coordinate(latitude: 64.1466, longitude: -21.9426)
    static let longyearbyen = Coordinate(latitude: 78.2232, longitude: 15.6267)
    static let northPole = Coordinate(latitude: 89.9, longitude: 0)

    /// A local time in `timeZone`.
    static func date(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0,
        in timeZone: TimeZone = istanbulZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute, second: second
        ))!
    }

    /// Decodes a fixture the way the client does.
    static func sunTimes(
        _ name: String,
        coordinate: Coordinate,
        day: CalendarDay? = nil,
        timeZone: TimeZone = istanbulZone
    ) throws -> SunTimes {
        let envelope = try JSONDecoder().decode(APIEnvelope.self, from: data(name))
        return try envelope.results().sunTimes(day: day, coordinate: coordinate, timeZone: timeZone)
    }

    /// Istanbul on October 18, 2026.
    static func istanbulDay() throws -> SunTimes {
        try sunTimes("istanbul-2026-10-18", coordinate: istanbul)
    }
}

/// A canned HTTP response.
struct StubResponse: Sendable {
    var status: Int
    var body: Data

    static func json(_ fixture: String, status: Int = 200) throws -> StubResponse {
        try StubResponse(status: status, body: Fixture.data(fixture))
    }

    static func text(_ text: String, status: Int) -> StubResponse {
        StubResponse(status: status, body: Data(text.utf8))
    }
}

typealias StubHandler = @Sendable (URLRequest) throws -> StubResponse

/// Answers requests from a handler registered for the request's host, so every test can run in parallel with its
/// own host. Nothing reaches the network.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url, let host = url.host, let handler = StubRegistry.shared.handler(for: host) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        StubRegistry.shared.record(request, for: host)
        do {
            let stub = try handler(request)
            guard let response = HTTPURLResponse(
                url: url, statusCode: stub.status, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class StubRegistry: @unchecked Sendable {
    static let shared = StubRegistry()

    private let lock = NSLock()
    private var handlers: [String: StubHandler] = [:]
    private var requests: [String: [URLRequest]] = [:]

    func register(_ handler: @escaping StubHandler, for host: String) {
        lock.withLock { handlers[host] = handler }
    }

    func handler(for host: String) -> StubHandler? {
        lock.withLock { handlers[host] }
    }

    func record(_ request: URLRequest, for host: String) {
        lock.withLock { requests[host, default: []].append(request) }
    }

    func requests(for host: String) -> [URLRequest] {
        lock.withLock { requests[host] ?? [] }
    }
}

/// A client wired to the stub, on a host of its own.
struct StubbedClient {
    let host: String
    let client: SunriseSunsetClient

    init(handler: @escaping StubHandler) {
        host = "stub-" + UUID().uuidString.lowercased() + ".sunrise.test"
        StubRegistry.shared.register(handler, for: host)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        client = SunriseSunsetClient(configuration: SunriseSunsetConfiguration(
            endpoint: URL(string: "https://" + host + "/json")!,
            session: URLSession(configuration: configuration)
        ))
    }

    /// A client that answers every request with `fixture`.
    init(fixture: String, status: Int = 200) {
        self.init { _ in try StubResponse.json(fixture, status: status) }
    }

    var requests: [URLRequest] {
        StubRegistry.shared.requests(for: host)
    }

    /// The query items of every request, by name.
    func queries() -> [[String: String]] {
        requests.map { request in
            let items = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
            var values: [String: String] = [:]
            for item in items {
                values[item.name] = item.value ?? ""
            }
            return values
        }
    }
}

/// The value of query parameter `name` in `request`.
func queryValue(_ name: String, in request: URLRequest) -> String? {
    guard let url = request.url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return nil
    }
    return components.queryItems?.first { $0.name == name }?.value
}
