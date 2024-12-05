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
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.4.0"),
        .package(url: "https://github.com/woodymelling/swift-parsing", branch: "async-parsing")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "FileTree",
            dependencies: [
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "Conversions", package: "swift-parsing")
            ]
        ),
        .testTarget(
            name: "FileTreeTests",
            dependencies: [
                "FileTree"
            ],
            resources: [
                .copy("Resources")
            ]
        ),
    ]
)
