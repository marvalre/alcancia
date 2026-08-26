// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Alcancia",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Alcancia", targets: ["Alcancia"]),
        .library(name: "AlcanciaCore", targets: ["AlcanciaCore"])
    ],
    targets: [
        .target(name: "AlcanciaCore"),
        .executableTarget(name: "Alcancia", dependencies: ["AlcanciaCore"]),
        .testTarget(name: "AlcanciaCoreTests", dependencies: ["AlcanciaCore"])
    ]
)
