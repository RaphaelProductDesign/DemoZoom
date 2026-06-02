// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DemoZoom",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DemoZoom", targets: ["DemoZoom"])
    ],
    targets: [
        .executableTarget(
            name: "DemoZoom",
            path: "DemoZoom"
        )
    ]
)
