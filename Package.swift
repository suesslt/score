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
        .testTarget(
            name: "ScoreTests",
            dependencies: ["Score"],
            path: "Tests/ScoreTests"
        ),
    ]
)
