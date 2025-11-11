// swift-tools-version:5.9
import PackageDescription
let package = Package(
    name: "space-cadet",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "SpaceCadet", targets: ["SpaceCadet"]),
        .executable(name: "SpaceCadetApp", targets: ["SpaceCadetApp"])
    ],
    targets: [
        .target(
            name: "SpaceCadet",
            path: "Sources/SpaceCadet",
            swiftSettings: [
                .define("HID_ENGINE_EXPERIMENTAL"),
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release))
            ],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation")
            ]
        ),
        // SpaceCadetCLI target removed
        .executableTarget(
            name: "SpaceCadetApp",
            dependencies: ["SpaceCadet"],
            path: "SpaceCadetApp/SpaceCadetApp"
        ),
        .testTarget(
            name: "SpaceCadetTests",
            dependencies: ["SpaceCadet"],
            path: "Tests/SpaceCadetTests"
        )
    ]
)
