// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_khipu",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "flutter-khipu", targets: ["flutter_khipu"])
    ],
    dependencies: [
        .package(url: "https://github.com/khipu/KhipuClientIOS.git", exact: "2.16.5")
    ],
    targets: [
        .target(
            name: "flutter_khipu",
            dependencies: [
                .product(name: "KhipuClientIOS", package: "KhipuClientIOS")
            ]
        )
    ]
)
