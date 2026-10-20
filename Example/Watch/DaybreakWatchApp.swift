import SunriseKit
import SunriseUI
import SwiftUI

@main
struct DaybreakWatchApp: App {
    @State private var store = SunStore.make(for: ScreenshotScene.requested)
    @State private var location = LocationProvider()

    var body: some Scene {
        WindowGroup {
            WatchRootView(scene: ScreenshotScene.requested)
                .environment(store)
                .environment(location)
        }
    }
}

/// Vertically paged screens: the sun arc, the golden hour and twilights, and the cities.
/// A screenshot launch shows one screen on its own.
struct WatchRootView: View {
    let scene: ScreenshotScene?

    @Environment(SunStore.self) private var store

    var body: some View {
        Group {
            switch scene {
            case .arc:
                WatchArcView()
            case .golden:
                WatchGoldenView()
            default:
                TabView {
                    WatchArcView()
                    WatchGoldenView()
                    WatchCitiesView()
                }
                .tabViewStyle(.verticalPage)
            }
        }
        .task(id: store.selected) {
            await store.load(store.selected)
        }
        .signalsScreenshotReady(scene, when: store.hasLoaded(store.selected))
    }
}

/// A spinner while loading, or the error with a retry button.
struct WatchLoadingView: View {
    @Environment(SunStore.self) private var store

    var body: some View {
        if case let .failed(message) = store.state(of: store.selected) {
            ScrollView {
                VStack(spacing: 8) {
                    Image(systemName: "icloud.slash")
                        .font(.title2)
                    Text(message)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                    Button("Try Again") {
                        Task { await store.load(store.selected, force: true) }
                    }
                }
            }
        } else {
            ProgressView()
        }
    }
}

/// A dark sky tinted by the phase.
struct WatchSky: View {
    let phase: SunPhase?

    var body: some View {
        LinearGradient(
            colors: [(phase ?? .night).color.opacity(0.55), .black],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
