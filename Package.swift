// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "space-cadet",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "SpaceCadet", targets: ["SpaceCadet"])
    ],
    targets: [
        .executableTarget(
            name: "SpaceCadet",
            path: "Sources/SpaceCadet",
            swiftSettings: [
                .define("HID_ENGINE_EXPERIMENTAL"),
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release)),
            ],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
            ]
        ),
        .testTarget(
            name: "SpaceCadetTests",
            dependencies: ["SpaceCadet"],
            path: "Tests/SpaceCadetTests"
        ),
    ]
)
