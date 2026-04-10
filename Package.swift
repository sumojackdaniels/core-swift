// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CoreSwift",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "CoreSwift", targets: ["CoreSwift"]),
    ],
    targets: [
        .target(name: "CoreSwift"),
        .testTarget(name: "CoreSwiftTests", dependencies: ["CoreSwift"]),
    ]
)
