// swift-tools-version:6.0
import PackageDescription

let modules = ["DesignSystem", "Settings", "Capture", "Annotation", "Pinning"]

let package = Package(
    name: "Snip",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Snip", targets: ["Snip"])
    ],
    targets: modules.flatMap { name -> [Target] in
        [
            .target(name: name, swiftSettings: [.swiftLanguageMode(.v5)]),
            .testTarget(
                name: "\(name)Tests",
                dependencies: [.target(name: name)],
                swiftSettings: [.swiftLanguageMode(.v5)]
            ),
        ]
    } + [
        .executableTarget(
            name: "Snip",
            dependencies: modules.map { .target(name: $0) },
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
