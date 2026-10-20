import Foundation
import Observation
import SunriseKit

/// Sun times per city, loaded from the live sunrise-sunset.org API.
@MainActor
@Observable
final class SunStore {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    /// Days per city, starting with the city's local today.
    private(set) var days: [City.ID: [SunTimes]] = [:]
    private(set) var states: [City.ID: LoadState] = [:]
    var selected: City = .istanbul

    let client: SunriseSunsetClient
    /// How many times a load is tried before it fails. Screenshot scenes retry, so a brief network hiccup on a CI
    /// runner does not fail the job; there is no fallback data, so a scene that cannot load never signals ready.
    let attempts: Int

    init(client: SunriseSunsetClient = .shared, attempts: Int = 1) {
        self.client = client
        self.attempts = max(1, attempts)
    }

    /// Always the live API. A screenshot scene tries harder, but shows only real data.
    static func make(for scene: ScreenshotScene?) -> SunStore {
        SunStore(attempts: scene == nil ? 1 : 4)
    }

    func state(of city: City) -> LoadState {
        states[city.id] ?? .idle
    }

    /// Whether `city` has at least `count` days loaded.
    func hasLoaded(_ city: City, days count: Int = 2) -> Bool {
        (days[city.id]?.count ?? 0) >= count
    }

    /// Today in `city` (its local day).
    func today(in city: City) -> SunTimes? {
        days[city.id]?.first
    }

    /// The loaded days of `city`, today first.
    func week(in city: City) -> [SunTimes] {
        days[city.id] ?? []
    }

    /// The next event in `city` after `now`, looking into tomorrow after the last dusk.
    func nextEvent(in city: City, after now: Date) -> SunEvent? {
        week(in: city).prefix(2).nextEvent(after: now)
    }

    /// The day containing `now` in `city`, so a screen left open past midnight moves on.
    func day(in city: City, at now: Date) -> SunTimes? {
        week(in: city).day(containing: now) ?? today(in: city)
    }

    /// Loads `count` days from today in `city`, unless they are already there.
    func load(_ city: City, days count: Int = 2, force: Bool = false) async {
        if !force, hasLoaded(city, days: count), days[city.id]?.first?.day == city.today() { return }
        states[city.id] = .loading
        var lastError: (any Error)?
        for attempt in 1...attempts {
            do {
                let loaded = try await client.sunTimes(
                    for: city.coordinate,
                    startingOn: city.today(),
                    count: count,
                    timeZone: city.timeZone
                )
                // Loads of different lengths can overlap (the list asks for 2 days, the detail for 7);
                // keep the longer one for the same starting day.
                let existing = days[city.id] ?? []
                if existing.first?.day != loaded.first?.day || existing.count <= loaded.count {
                    days[city.id] = loaded
                }
                states[city.id] = .loaded
                return
            } catch {
                lastError = error
                guard attempt < attempts, !Task.isCancelled else { break }
                try? await Task.sleep(for: .seconds(Double(attempt * 3)))
            }
        }
        states[city.id] = .failed(lastError?.localizedDescription ?? "The sun times could not be loaded.")
    }

    /// Loads today and tomorrow for every city at once.
    func loadAll(_ cities: [City]) async {
        await withTaskGroup(of: Void.self) { group in
            for city in cities {
                group.addTask { await self.load(city) }
            }
        }
    }

    /// Whether every city in `cities` has today and tomorrow.
    func hasLoadedAll(_ cities: [City]) -> Bool {
        cities.allSatisfy { hasLoaded($0) }
    }

    /// The first failure among `cities`, if any.
    func failure(among cities: [City]) -> String? {
        for city in cities {
            if case let .failed(message) = state(of: city) { return message }
        }
        return nil
    }
}
