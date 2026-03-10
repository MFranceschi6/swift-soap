// swift-tools-version: 6.0

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SwiftSOAP",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "SwiftSOAPCore", targets: ["SwiftSOAPCore"]),
        .library(name: "SwiftSOAPXML", targets: ["SwiftSOAPXML"]),
        .library(name: "SwiftSOAPWSDL", targets: ["SwiftSOAPWSDL"]),
        .library(name: "SwiftSOAPClientAsync", targets: ["SwiftSOAPClientAsync"]),
        .library(name: "SwiftSOAPServerAsync", targets: ["SwiftSOAPServerAsync"]),
        .library(name: "SwiftSOAPClientNIO", targets: ["SwiftSOAPClientNIO"]),
        .library(name: "SwiftSOAPServerNIO", targets: ["SwiftSOAPServerNIO"]),
        .library(name: "SwiftSOAPXMLMacros", targets: ["SwiftSOAPXMLMacros"]),
        .library(name: "SwiftSOAPXMLTestSupport", targets: ["SwiftSOAPXMLTestSupport"]),
        .plugin(name: "SwiftSOAPCodeGenPlugin", targets: ["SwiftSOAPCodeGenPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0")
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
            name: "SwiftSOAPCompatibility",
            dependencies: ["CLibXML2"]
        ),
        .target(
            name: "SwiftSOAPXMLCShim",
            dependencies: ["CLibXML2"],
            publicHeadersPath: "include"
        ),
        .target(
            name: "SwiftSOAPXMLOwnership6",
            dependencies: [
                "SwiftSOAPCompatibility",
                "SwiftSOAPXMLCShim"
            ]
        ),
        .target(
            name: "SwiftSOAPCore",
            dependencies: [
                "SwiftSOAPCompatibility",
                "SwiftSOAPXML",
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .target(
            name: "SwiftSOAPWSDL",
            dependencies: [
                "SwiftSOAPCompatibility",
                "SwiftSOAPXML",
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .target(
            name: "SwiftSOAPCodeGenCore",
            dependencies: [
                "SwiftSOAPCompatibility",
                "SwiftSOAPCore",
                "SwiftSOAPWSDL",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax")
            ]
        ),
        .executableTarget(
            name: "SwiftSOAPCodeGen",
            dependencies: ["SwiftSOAPCodeGenCore"]
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
                "SwiftSOAPCompatibility",
                "SwiftSOAPXMLCShim",
                "SwiftSOAPXMLOwnership6",
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .macro(
            name: "SwiftSOAPXMLMacroImplementation",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax")
            ]
        ),
        .target(
            name: "SwiftSOAPXMLMacros",
            dependencies: [
                "SwiftSOAPXML",
                "SwiftSOAPXMLMacroImplementation"
            ]
        ),
        .target(
            name: "SwiftSOAPXMLTestSupport",
            dependencies: ["SwiftSOAPXML"]
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
                .product(name: "NIOEmbedded", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio")
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
            dependencies: [
                "SwiftSOAPXML",
                "SwiftSOAPXMLTestSupport",
                "SwiftSOAPXMLMacros",
                "SwiftSOAPXMLMacroImplementation",
            ]
        ),
        .testTarget(
            name: "SwiftSOAPWSDLTests",
            dependencies: ["SwiftSOAPWSDL"]
        ),
        .testTarget(
            name: "SwiftSOAPCodeGenCoreTests",
            dependencies: [
                "SwiftSOAPCodeGenCore",
                "SwiftSOAPWSDL",
                "SwiftSOAPXML",
                "SwiftSOAPXMLTestSupport"
            ],
            exclude: ["Fixtures"]
        ),
        .plugin(
            name: "SwiftSOAPCodeGenPlugin",
            capability: .buildTool(),
            dependencies: ["SwiftSOAPCodeGen"]
        ),
    ],
    swiftLanguageModes: [
        .v6
    ]
)
