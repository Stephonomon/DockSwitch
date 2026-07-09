// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "DockSwitch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DockSwitch", targets: ["DockSwitch"])
    ],
    targets: [
        .executableTarget(
            name: "DockSwitch"
        ),
        .testTarget(
            name: "DockSwitchTests",
            dependencies: ["DockSwitch"]
        )
    ],
    swiftLanguageModes: [.v6]
)
