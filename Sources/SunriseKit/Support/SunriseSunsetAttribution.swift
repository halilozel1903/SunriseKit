import Foundation

/// The credit sunrise-sunset.org asks for wherever its data is shown: a visible link to sunrise-sunset.org next to
/// the data or in an About screen, or on devices with screens the text "Sun data by Sunrise-Sunset.org".
public enum SunriseSunsetAttribution {
    /// "Sun data by Sunrise-Sunset.org"
    public static let text = "Sun data by Sunrise-Sunset.org"
    /// https://sunrise-sunset.org
    public static let url = URL(string: "https://sunrise-sunset.org")!
    /// The API documentation.
    public static let apiURL = URL(string: "https://sunrise-sunset.org/api")!
}
