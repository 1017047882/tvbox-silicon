// swift-tools-version: 6.0
import PackageDescription

// Compile the real app sources for iPhone without linking the separately built JVM/Python/Node runtimes.
// The workflow creates App -> ../../App before invoking this validation-only package.
let package = Package(
    name: "IOS15AppCheck",
    platforms: [.iOS(.v15)],
    dependencies: [
        .package(path: "../TVCore"),
        .package(url: "https://github.com/pointfreeco/swift-perception", exact: "1.6.0"),
        .package(url: "https://github.com/johnpatrickmorgan/NavigationBackport", exact: "0.9.0")
    ],
    targets: [
        .target(name: "TVBoxIOS15Check", dependencies: [
            .product(name: "TVCore", package: "TVCore"),
            .product(name: "Perception", package: "swift-perception"),
            .product(name: "NavigationBackport", package: "NavigationBackport")
        ], path: "App", exclude: ["Resources"])
    ]
)
