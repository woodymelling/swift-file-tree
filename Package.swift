// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-file-tree",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "FileTree",
            targets: ["FileTree"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.3.9"),
        .package(url: "https://github.com/woodymelling/swift-parsing", branch: "async-parsing")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "FileTree",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "Conversions", package: "swift-parsing")
            ]
        ),
        .testTarget(
            name: "FileTreeTests",
            dependencies: [
                "FileTree",
                .product(name: "DependenciesTestSupport", package: "swift-dependencies")
            ],
            resources: [
                .copy("Resources")
            ]
        ),
    ]
)
