// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-apple-books",
    // SQLite is read through swift-sqlite-reader; nothing is vendored. macOS
    // only — Books' stores on a Mac are the ones this reads.
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AppleBooks", targets: ["AppleBooks"]),
    ],
    dependencies: [
        .package(url: "https://github.com/arraypress/swift-sqlite-reader.git", from: "0.1.0"),
    ],
    targets: [
        .target(name: "AppleBooks", dependencies: [
            .product(name: "SQLiteReader", package: "swift-sqlite-reader"),
        ]),
        .testTarget(name: "AppleBooksTests", dependencies: ["AppleBooks"]),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
