// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-apple-books",
    // SQLite3 is in the OS; nothing is vendored and nothing is fetched. macOS
    // only — Books' stores on a Mac are the ones this reads.
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AppleBooks", targets: ["AppleBooks"]),
    ],
    targets: [
        .target(name: "AppleBooks"),
        .testTarget(name: "AppleBooksTests", dependencies: ["AppleBooks"]),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
