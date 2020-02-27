// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "tun2socks",
    products: [
        .library(
            name: "tun2socks",
            targets: ["tun2socks"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "tun2socks",
            dependencies: ["lwip"]
        ),
        .target(
            name: "lwip"
        ),
    ]
)
