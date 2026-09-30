// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ReviewGate",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ReviewGate", targets: ["ReviewGate"])
    ],
    targets: [
        .target(name: "ReviewGate"),
        .testTarget(name: "ReviewGateTests", dependencies: ["ReviewGate"])
    ]
)
