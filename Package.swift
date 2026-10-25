// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "ThreadedCgroupRepro",
    platforms: [.macOS("27.0")],
    dependencies: [
        .package(url: "https://github.com/apple/containerization.git", exact: "0.53.0")
    ],
    targets: [
        .executableTarget(
            name: "ThreadedCgroupRepro",
            dependencies: [.product(name: "Containerization", package: "containerization")],
            swiftSettings: [.unsafeFlags(["-strict-concurrency=complete", "-warnings-as-errors"])]
        )
    ],
    swiftLanguageModes: [.v6]
)
