// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Synapse",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Synapse",
            targets: ["Synapse"]
        )
    ],
    dependencies: [
        // Add any external dependencies here
    ],
    targets: [
        .executableTarget(
            name: "Synapse",
            dependencies: [],
            path: "Synapse"
        ),
        .testTarget(
            name: "SynapseTests",
            dependencies: ["Synapse"],
            path: "Tests/SynapseTests"
        )
    ]
)