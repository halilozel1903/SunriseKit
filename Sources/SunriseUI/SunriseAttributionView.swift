import SunriseKit
import SwiftUI

/// "Sun data by Sunrise-Sunset.org", linking to sunrise-sunset.org as its terms ask.
public struct SunriseAttributionView: View {
    public init() {}

    public var body: some View {
        Link(destination: SunriseSunsetAttribution.url) {
            Text(SunriseSunsetAttribution.text)
                .underline()
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

/// A capsule with the phase's symbol and title.
public struct SunPhaseBadge: View {
    let phase: SunPhase
    var compact: Bool

    public init(_ phase: SunPhase, compact: Bool = false) {
        self.phase = phase
        self.compact = compact
    }

    public var body: some View {
        Label(compact ? phase.shortTitle : phase.title, systemImage: phase.symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(phase.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(phase.color.opacity(0.35), in: Capsule())
    }
}
