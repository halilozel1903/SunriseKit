import SunriseKit
import SwiftUI

/// The sun's height over one local day as a curve, with the horizon, the sunrise and sunset points and the sun at
/// `now`. Midnight is at both edges and solar noon near the middle.
public struct SunArcView: View {
    let times: SunTimes
    let now: Date
    var lineWidth: CGFloat

    public init(times: SunTimes, now: Date, lineWidth: CGFloat = 3) {
        self.times = times
        self.now = now
        self.lineWidth = lineWidth
    }

    public var body: some View {
        Canvas { context, size in
            let layout = ArcLayout(times: times, size: size, inset: lineWidth * 3)
            let curve = layout.curve()

            // Daylight under the curve, above the horizon.
            var above = curve
            above.addLine(to: CGPoint(x: layout.x(1), y: layout.horizonY))
            above.addLine(to: CGPoint(x: layout.x(0), y: layout.horizonY))
            above.closeSubpath()
            context.drawLayer { layer in
                layer.clip(to: Path(CGRect(x: 0, y: 0, width: size.width, height: layout.horizonY)))
                layer.fill(above, with: .linearGradient(
                    Gradient(colors: [SunPalette.sun.opacity(0.45), SunPalette.golden.opacity(0.05)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: layout.horizonY)
                ))
                layer.stroke(curve, with: .color(SunPalette.sun), lineWidth: lineWidth)
            }
            // The night part of the curve.
            context.drawLayer { layer in
                layer.clip(to: Path(CGRect(x: 0, y: layout.horizonY, width: size.width, height: size.height - layout.horizonY)))
                layer.stroke(curve, with: .color(.white.opacity(0.35)),
                             style: StrokeStyle(lineWidth: lineWidth * 0.7, lineCap: .round, dash: [lineWidth, lineWidth * 1.6]))
            }

            // The horizon.
            var horizon = Path()
            horizon.move(to: CGPoint(x: 0, y: layout.horizonY))
            horizon.addLine(to: CGPoint(x: size.width, y: layout.horizonY))
            context.stroke(horizon, with: .color(SunPalette.horizon), lineWidth: 1)

            // Sunrise and sunset.
            for event in [times.sunrise, times.sunset].compactMap({ $0 }) {
                let x = layout.x(layout.timeline.fraction(at: event))
                let dot = CGRect(x: x - lineWidth, y: layout.horizonY - lineWidth, width: lineWidth * 2, height: lineWidth * 2)
                context.fill(Path(ellipseIn: dot), with: .color(.white.opacity(0.8)))
            }

            // The sun now.
            let fraction = layout.timeline.fraction(at: now)
            let point = CGPoint(x: layout.x(fraction), y: layout.y(times.altitude(at: now)))
            let phase = times.phase(at: now)
            let radius = lineWidth * 2.6
            let glow = CGRect(x: point.x - radius * 2.2, y: point.y - radius * 2.2, width: radius * 4.4, height: radius * 4.4)
            context.fill(Path(ellipseIn: glow), with: .radialGradient(
                Gradient(colors: [phase.accent.opacity(0.55), phase.accent.opacity(0)]),
                center: point, startRadius: 0, endRadius: radius * 2.2
            ))
            let disc = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: disc), with: .color(phase >= .goldenHour ? SunPalette.sun : phase.accent))
            context.stroke(Path(ellipseIn: disc), with: .color(.white.opacity(0.9)), lineWidth: 1)
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Sun position"))
        .accessibilityValue(Text("\(times.phase(at: now).title), \(Int(times.altitude(at: now).rounded())) degrees"))
    }
}

/// Maps the day onto the view: time to x, altitude to y, with more room above the horizon than below.
struct ArcLayout {
    let times: SunTimes
    let size: CGSize
    let inset: CGFloat
    let timeline: DayTimeline
    let horizonY: CGFloat
    let maximumAltitude: Double
    let minimumAltitude: Double

    init(times: SunTimes, size: CGSize, inset: CGFloat) {
        self.times = times
        self.size = size
        self.inset = inset
        timeline = times.timeline
        let geometry = times.geometry
        maximumAltitude = max(geometry.noonAltitude, 8)
        minimumAltitude = min(geometry.midnightAltitude, -8)
        horizonY = inset + (size.height - inset * 2) * 0.62
    }

    func x(_ fraction: Double) -> CGFloat {
        inset + (size.width - inset * 2) * fraction
    }

    func y(_ altitude: Double) -> CGFloat {
        if altitude >= 0 {
            return horizonY - (horizonY - inset) * altitude / maximumAltitude
        }
        return horizonY + (size.height - inset - horizonY) * altitude / minimumAltitude
    }

    func curve(samples: Int = 120) -> Path {
        var path = Path()
        for index in 0...samples {
            let fraction = Double(index) / Double(samples)
            let point = CGPoint(x: x(fraction), y: y(times.altitude(at: timeline.date(at: fraction))))
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}
