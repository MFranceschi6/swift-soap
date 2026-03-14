// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CalculatorClient",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "CalculatorClient",
            dependencies: [
                .product(name: "SwiftSOAPClientAsync", package: "swift-soap")
            ],
            path: "Sources/CalculatorClient",
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
