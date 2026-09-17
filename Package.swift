// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Ririku",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Ririku", targets: ["Ririku"]),
        .executable(name: "RirikuHost", targets: ["RirikuHost"])
    ],
    targets: [
        .target(name: "RirikuCore"),
        .executableTarget(name: "Ririku", dependencies: ["RirikuCore"]),
        .executableTarget(name: "RirikuHost", dependencies: ["RirikuCore"]),
        .testTarget(name: "RirikuCoreTests", dependencies: ["RirikuCore"]),
        .testTarget(name: "RirikuTests", dependencies: ["Ririku"])
    ],
    swiftLanguageModes: [.v5]
)
