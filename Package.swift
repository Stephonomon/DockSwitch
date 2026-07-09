// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Dynamic Dock App",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Dynamic Dock App", targets: ["Dynamic Dock App"])
    ],
    targets: [
        .executableTarget(
            name: "Dynamic Dock App"
        )
    ],
    swiftLanguageModes: [.v6]
)
