// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftSOAP",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "SwiftSOAPCore", targets: ["SwiftSOAPCore"]),
        .library(name: "SwiftSOAPXML", targets: ["SwiftSOAPXML"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0")
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
            name: "SwiftSOAPXMLTests",
            dependencies: ["SwiftSOAPXML"]
        ),
    ],
    swiftLanguageModes: [
        .v5
    ]
)
