// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Score",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "Score", targets: ["Score"]),
        .library(name: "ScoreUI", targets: ["ScoreUI"]),
        .library(name: "ScoreKeychain", targets: ["ScoreKeychain"]),
    ],
    targets: [
        .target(
            name: "Score",
            path: "Sources/Score",
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        ),
        .target(
            name: "ScoreUI",
            dependencies: ["Score"],
            path: "Sources/ScoreUI"
        ),
        .target(
            name: "ScoreKeychain",
            path: "Sources/ScoreKeychain",
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        ),
        .testTarget(
            name: "ScoreKeychainTests",
            dependencies: ["ScoreKeychain"],
            path: "Tests/ScoreKeychainTests"
        ),
        .testTarget(
            name: "ScoreTests",
            dependencies: ["Score"],
            path: "Tests/ScoreTests"
        ),
    ]
)
