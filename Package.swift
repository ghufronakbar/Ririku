// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchBox",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NotchBox", targets: ["NotchBox"]),
        .executable(name: "NotchBoxHost", targets: ["NotchBoxHost"])
    ],
    targets: [
        .target(name: "NotchCore"),
        .executableTarget(name: "NotchBox", dependencies: ["NotchCore"]),
        .executableTarget(name: "NotchBoxHost", dependencies: ["NotchCore"])
    ],
    swiftLanguageModes: [.v5]
)
