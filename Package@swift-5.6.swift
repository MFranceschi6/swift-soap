// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "SwiftSOAP",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "SwiftSOAPCore", targets: ["SwiftSOAPCore"]),
        .library(name: "SwiftSOAPXML", targets: ["SwiftSOAPXML"]),
        .library(name: "SwiftSOAPClientAsync", targets: ["SwiftSOAPClientAsync"]),
        .library(name: "SwiftSOAPServerAsync", targets: ["SwiftSOAPServerAsync"]),
        .library(name: "SwiftSOAPClientNIO", targets: ["SwiftSOAPClientNIO"]),
        .library(name: "SwiftSOAPServerNIO", targets: ["SwiftSOAPServerNIO"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0")
    ],
    targets: [
        .systemLibrary(
            name: "CLibXML2",
            pkgConfig: "libxml-2.0",
            providers: [
                .brew(["libxml2"]),
                .apt(["libxml2-dev"])
            ]
        ),
        .target(
            name: "SwiftSOAPCore",
            dependencies: [
                "SwiftSOAPXML",
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .target(
            name: "SwiftSOAPClientAsync",
            dependencies: ["SwiftSOAPCore"]
        ),
        .target(
            name: "SwiftSOAPServerAsync",
            dependencies: ["SwiftSOAPCore"]
        ),
        .target(
            name: "SwiftSOAPClientNIO",
            dependencies: [
                "SwiftSOAPCore",
                .product(name: "NIOCore", package: "swift-nio")
            ]
        ),
        .target(
            name: "SwiftSOAPServerNIO",
            dependencies: [
                "SwiftSOAPCore",
                .product(name: "NIOCore", package: "swift-nio")
            ]
        ),
        .target(
            name: "SwiftSOAPXML",
            dependencies: [
                "CLibXML2",
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(
            name: "SwiftSOAPCoreTests",
            dependencies: ["SwiftSOAPCore"]
        ),
        .testTarget(
            name: "SwiftSOAPClientAsyncTests",
            dependencies: ["SwiftSOAPClientAsync"]
        ),
        .testTarget(
            name: "SwiftSOAPServerAsyncTests",
            dependencies: ["SwiftSOAPServerAsync"]
        ),
        .testTarget(
            name: "SwiftSOAPClientNIOTests",
            dependencies: [
                "SwiftSOAPClientNIO",
                .product(name: "NIOEmbedded", package: "swift-nio")
            ]
        ),
        .testTarget(
            name: "SwiftSOAPServerNIOTests",
            dependencies: [
                "SwiftSOAPServerNIO",
                .product(name: "NIOEmbedded", package: "swift-nio")
            ]
        ),
        .testTarget(
            name: "SwiftSOAPXMLTests",
            dependencies: ["SwiftSOAPXML"]
        ),
    ]
)
