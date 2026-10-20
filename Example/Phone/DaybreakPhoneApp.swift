import SunriseKit
import SunriseUI
import SwiftUI

@main
struct DaybreakPhoneApp: App {
    @State private var store = SunStore.make(for: ScreenshotScene.requested)
    @State private var location = LocationProvider()

    var body: some Scene {
        WindowGroup {
            PhoneRootView(scene: ScreenshotScene.requested)
                .environment(store)
                .environment(location)
                .preferredColorScheme(.dark)
        }
    }
}

/// The city list, pushing a city's detail. The detail scene opens Reykjavik directly.
struct PhoneRootView: View {
    let scene: ScreenshotScene?

    @Environment(SunStore.self) private var store
    @State private var path: [City]

    init(scene: ScreenshotScene?) {
        self.scene = scene
        _path = State(initialValue: scene == .detail ? [.reykjavik] : [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            CitiesScreen()
                .navigationDestination(for: City.self) { city in
                    CityDetailScreen(city: city)
                }
        }
        .signalsScreenshotReady(scene, when: isReady)
    }

    private var isReady: Bool {
        switch scene {
        case .detail: store.hasLoaded(.reykjavik, days: 7)
        case .cities: store.hasLoadedAll(City.all)
        default: false
        }
    }
}

/// Colours of the iPhone app.
enum Theme {
    static let background = Color(red: 0.04, green: 0.05, blue: 0.11)
    static let card = Color.white.opacity(0.07)
}

extension View {
    /// A dark, opaque navigation bar with an inline title. iOS 26 bars are transparent by default and leave the large
    /// title out with a pinned bar background.
    func daybreakNavigationBar() -> some View {
        navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

/// A rounded card with a small caption.
struct Card<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title.uppercased(), systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// A spinner while loading, or the error with a retry button.
struct PhoneLoadingView: View {
    let failure: String?
    let retry: () -> Void

    var body: some View {
        Group {
            if let failure {
                ContentUnavailableView {
                    Label("No Sun Times", systemImage: "icloud.slash")
                } description: {
                    Text(failure)
                } actions: {
                    Button("Try Again", action: retry)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }
}
