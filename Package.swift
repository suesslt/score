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
        .library(name: "ScoreQueue", targets: ["ScoreQueue"]),
        .library(name: "ScoreQueueGRDB", targets: ["ScoreQueueGRDB"]),
    ],
    dependencies: [
        // ONLY `ScoreQueueGRDB` links this — `Score`, `ScoreUI`,
        // `ScoreKeychain` and `ScoreQueue` stay dependency-free, so a consumer
        // that does not use the SQLite store never builds GRDB.
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
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
        .target(
            name: "ScoreQueue",
            path: "Sources/ScoreQueue"
        ),
        .target(
            name: "ScoreQueueGRDB",
            dependencies: ["ScoreQueue", .product(name: "GRDB", package: "GRDB.swift")],
            path: "Sources/ScoreQueueGRDB"
        ),
        .testTarget(
            name: "ScoreQueueTests",
            dependencies: ["ScoreQueue"],
            path: "Tests/ScoreQueueTests"
        ),
        .testTarget(
            name: "ScoreQueueGRDBTests",
            dependencies: ["ScoreQueueGRDB"],
            path: "Tests/ScoreQueueGRDBTests"
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
