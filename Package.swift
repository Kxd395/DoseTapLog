// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DoseTrack",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "DoseTrack",
            targets: ["DoseTrack"])
    ],
    targets: [
        .target(
            name: "DoseTrack",
            path: "ios",
            exclude: [
                "Tests",
                "Widget"
            ]
        ),
        .testTarget(
            name: "DoseTrackTests",
            dependencies: ["DoseTrack"],
            path: "ios/Tests"
        )
    ]
)
