import Foundation
import SwiftUI

/// Scenes used by CI to capture the README screenshots.
/// Launch with `-screenshot <scene>`; normal launches are unaffected and use the live API.
///
/// Every scene loads real sun times from the live sunrise-sunset.org API for today, retrying a few times, and shows
/// them at the real current time (the sun's position and the countdown are whatever they were when CI ran). There is
/// no fallback data: when the API cannot be reached, the scene never signals ready and the screenshot job fails.
enum ScreenshotScene: String {
    /// Apple Watch: Istanbul's sun arc with the sun now, the phase and the next event countdown.
    case arc
    /// Apple Watch: Istanbul's golden hour card and twilight phases (the blue hour is further down).
    case golden
    /// iPhone: every city with today's sunrise, sunset, day length and phase.
    case cities
    /// iPhone: Reykjavik's detail screen with the arc, golden hour, twilights and the week.
    case detail

    /// The scene this launch asked for.
    static var requested: ScreenshotScene? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return ScreenshotScene(rawValue: arguments[index + 1])
    }
}

extension View {
    /// Tells scripts/screenshots.sh that the scene is on screen by writing `tmp/screenshot-ready` into the app
    /// container, once `isReady` is true and the frame had time to settle.
    func signalsScreenshotReady(_ scene: ScreenshotScene?, when isReady: Bool) -> some View {
        task(id: isReady) {
            guard let scene, isReady else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            let marker = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("screenshot-ready")
            try? scene.rawValue.write(to: marker, atomically: true, encoding: .utf8)
        }
    }
}
