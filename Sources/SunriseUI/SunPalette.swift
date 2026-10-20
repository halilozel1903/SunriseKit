import SunriseKit
import SwiftUI

extension SunPhase {
    /// A sky colour for the phase, from deep night blue to daylight.
    public var color: Color {
        switch self {
        case .night: Color(red: 0.07, green: 0.09, blue: 0.20)
        case .astronomicalTwilight: Color(red: 0.13, green: 0.16, blue: 0.36)
        case .nauticalTwilight: Color(red: 0.19, green: 0.26, blue: 0.54)
        case .civilTwilight: Color(red: 0.29, green: 0.42, blue: 0.80)
        case .goldenHour: Color(red: 0.98, green: 0.66, blue: 0.20)
        case .day: Color(red: 0.49, green: 0.78, blue: 0.98)
        }
    }

    /// A colour for text and symbols naming the phase on a dark background.
    public var accent: Color {
        switch self {
        case .night: Color(red: 0.62, green: 0.68, blue: 0.95)
        case .astronomicalTwilight: Color(red: 0.66, green: 0.62, blue: 1.0)
        case .nauticalTwilight: Color(red: 0.50, green: 0.66, blue: 1.0)
        case .civilTwilight: Color(red: 0.45, green: 0.66, blue: 1.0)
        case .goldenHour: Color(red: 1.0, green: 0.74, blue: 0.30)
        case .day: Color(red: 1.0, green: 0.86, blue: 0.35)
        }
    }
}

/// Colours shared by the views.
public enum SunPalette {
    public static let sun = Color(red: 1.0, green: 0.80, blue: 0.30)
    public static let golden = Color(red: 1.0, green: 0.66, blue: 0.22)
    public static let blue = Color(red: 0.36, green: 0.55, blue: 1.0)
    public static let horizon = Color.white.opacity(0.35)
}
