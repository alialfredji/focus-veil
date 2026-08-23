// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "FocusVeil",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "FocusVeil", targets: ["FocusVeil"]),
    ],
    targets: [
        .executableTarget(
            name: "FocusVeil",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("QuartzCore"),
            ]
        ),
        .testTarget(
            name: "FocusVeilTests",
            dependencies: ["FocusVeil"]
        ),
    ]
)
