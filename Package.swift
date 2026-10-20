// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SunriseKit",
    platforms: [
        .watchOS(.v10),
        .iOS(.v17),
        // macOS only so `swift test` runs on CI; the views are made for Apple Watch and iPhone.
        .macOS(.v14),
    ],
    products: [
        .library(name: "SunriseKit", targets: ["SunriseKit"]),
        .library(name: "SunriseUI", targets: ["SunriseUI"]),
    ],
    targets: [
        .target(name: "SunriseKit"),
        .target(name: "SunriseUI", dependencies: ["SunriseKit"]),
        .testTarget(
            name: "SunriseKitTests",
            dependencies: ["SunriseKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
