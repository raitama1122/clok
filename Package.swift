// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CLOK",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "clok", targets: ["CLOK"])
    ],
    dependencies: [
        .package(path: "Packages/linenoise-swift")
    ],
    targets: [
        .executableTarget(
            name: "CLOK",
            dependencies: [.product(name: "LineNoise", package: "linenoise-swift")],
            path: "Sources/CLOK",
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        )
    ]
)
