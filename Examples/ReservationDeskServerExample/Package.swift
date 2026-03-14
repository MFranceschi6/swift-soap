// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ReservationDeskServerExample",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "ReservationDeskServerExample",
            dependencies: [
                .product(name: "SwiftSOAPCore", package: "swift-soap"),
                .product(name: "SwiftSOAPServerAsync", package: "swift-soap"),
                .product(name: "SwiftSOAPServerNIO", package: "swift-soap"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOEmbedded", package: "swift-nio")
            ],
            path: "Sources/ReservationDeskServerExample",
            exclude: [
                "swift-soap-codegen.json"
            ],
            plugins: [
                .plugin(name: "SwiftSOAPCodeGenPlugin", package: "swift-soap")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
