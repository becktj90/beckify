// swift-tools-version: 5.9
//
// Pure-Swift field-EE calculator math. No UIKit/SwiftUI.
// Runs `swift test` on Linux or macOS; the iOS app links this package.

import PackageDescription

let package = Package(
    name: "BeckifyMath",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "BeckifyMath", targets: ["BeckifyMath"]),
    ],
    targets: [
        .target(name: "BeckifyMath"),
        .testTarget(
            name: "BeckifyMathTests",
            dependencies: ["BeckifyMath"]
        ),
    ]
)
