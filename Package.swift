// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BatteryIndicator",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "BatteryCore", targets: ["BatteryCore"]),
        .library(name: "BatteryData", targets: ["BatteryData"]),
        .library(name: "BatteryUI", targets: ["BatteryUI"]),
    ],
    targets: [
        .target(name: "BatteryCore"),
        .target(
            name: "BatteryData",
            dependencies: ["BatteryCore"]
        ),
        .target(
            name: "BatteryUI",
            dependencies: ["BatteryCore", "BatteryData"]
        ),
    ]
)
