// swift-tools-version: 5.9
import PackageDescription

// Exercise the production camera service without opening a camera or the UI.
let package = Package(
    name: "MacCapture",
    platforms: [.macOS(.v13)],
    dependencies: [.package(path: "../SharedKit")],
    targets: [
        .target(name: "MacCapture", dependencies: [.product(name: "SharedKit", package: "SharedKit")], path: "Sources/Capture"),
        .testTarget(name: "MacCaptureTests", dependencies: ["MacCapture"], path: "Tests")
    ]
)
