import Foundation
import XCTest

final class PluginBuildIntegrationTests: XCTestCase {
    private struct FixtureBuildFailure: LocalizedError {
        let output: String

        var errorDescription: String? {
            "swift build failed for plugin fixture.\n\(output)"
        }
    }

    func test_buildToolPlugin_generatesSourcesInPluginWorkDirectory() throws {
        let fileManager = FileManager.default
        let repositoryRoot = fileManager.currentDirectoryPath
        let toolchain = FixtureSwiftToolchainSupport.current

        let fixtureRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("swift-soap-plugin-fixture-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: fixtureRoot) }

        try makeFixturePackage(
            at: fixtureRoot,
            repositoryRoot: repositoryRoot,
            toolchain: toolchain
        )
        try runSwiftBuild(packagePath: fixtureRoot)

        let expectedGeneratedFileName = "PluginFixture+GeneratedSOAP.swift"
        let buildDirectory = fixtureRoot.appendingPathComponent(".build", isDirectory: true)
        let generatedFileURL = try findFile(named: expectedGeneratedFileName, under: buildDirectory)

        XCTAssertNotNil(generatedFileURL, "Expected plugin-generated file '\(expectedGeneratedFileName)' under \(buildDirectory.path)")

        if let generatedFileURL {
            let generatedSource = try String(contentsOf: generatedFileURL, encoding: .utf8)
            XCTAssertFalse(generatedSource.isEmpty)
        }
    }

    private func makeFixturePackage(
        at fixtureRoot: URL,
        repositoryRoot: String,
        toolchain: FixtureSwiftToolchainSupport
    ) throws {
        let escapedRepositoryRoot = repositoryRoot
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let packageManifest = """
        // swift-tools-version: \(toolchain.fixtureToolsVersion)
        import PackageDescription

        let package = Package(
            name: "PluginFixture",
            platforms: [
                .macOS(.v10_15)
            ],
            dependencies: [
                .package(path: "\(escapedRepositoryRoot)")
            ],
            targets: [
                .target(
                    name: "PluginGeneratedClient",
                    dependencies: [
                        .product(name: "SwiftSOAPCore", package: "swift-soap"),
                        .product(name: "SwiftSOAPClientAsync", package: "swift-soap"),
                        .product(name: "SwiftSOAPServerAsync", package: "swift-soap")
                    ],
                    exclude: [
                        "service.wsdl",
                        "swift-soap-codegen.json"
                    ],
                    plugins: [
                        .plugin(name: "SwiftSOAPCodeGenPlugin", package: "swift-soap")
                    ]
                )
            ]
        )
        """

        let sourceDirectory = fixtureRoot.appendingPathComponent("Sources/PluginGeneratedClient", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)

        try packageManifest.write(
            to: fixtureRoot.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        let placeholderSource = """
        import SwiftSOAPCore

        public enum FixtureMarker {
            public static let isEnabled = true
        }
        """
        try placeholderSource.write(
            to: sourceDirectory.appendingPathComponent("FixtureMarker.swift"),
            atomically: true,
            encoding: .utf8
        )

        try makeWSDL().write(
            to: sourceDirectory.appendingPathComponent("service.wsdl"),
            atomically: true,
            encoding: .utf8
        )

        let codeGenConfiguration = """
        {
          "wsdlPath": "Sources/PluginGeneratedClient/service.wsdl",
          "moduleName": "PluginFixture",
          "outputMode": "build",
          "buildOutputDirectory": ".build/swift-soap-codegen",
          "exportOutputDirectory": "Sources/Generated",
          "runtimeTargets": ["async"],
          "generationScope": ["client", "server"],
          "targetSwiftVersion": "\(toolchain.codeGenTargetSwiftVersionString)",
          "syntaxFeatures": {}
        }
        """
        try codeGenConfiguration.write(
            to: sourceDirectory.appendingPathComponent("swift-soap-codegen.json"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func runSwiftBuild(packagePath: URL) throws {
        let logURL = packagePath.appendingPathComponent("swift-build.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "build", "--package-path", packagePath.path]
        process.currentDirectoryURL = packagePath

        let logHandle = try FileHandle(forWritingTo: logURL)
        defer { try? logHandle.close() }
        process.standardOutput = logHandle
        process.standardError = logHandle

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let output = try String(contentsOf: logURL, encoding: .utf8)
            throw FixtureBuildFailure(output: output)
        }
    }

    private func findFile(named fileName: String, under directory: URL) throws -> URL? {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return nil
        }

        for case let fileURL as URL in enumerator where fileURL.lastPathComponent == fileName {
            return fileURL
        }

        return nil
    }

    private func makeWSDL() -> String {
        """
        <wsdl:definitions
            xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
            xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
            xmlns:tns="urn:plugin-fixture"
            xmlns:xsd="http://www.w3.org/2001/XMLSchema"
            targetNamespace="urn:plugin-fixture"
            name="PluginFixtureService">
          <wsdl:types>
            <xsd:schema targetNamespace="urn:plugin-fixture">
              <xsd:complexType name="FixturePayload">
                <xsd:sequence>
                  <xsd:element name="value" type="xsd:string"/>
                </xsd:sequence>
              </xsd:complexType>
            </xsd:schema>
          </wsdl:types>
          <wsdl:message name="InputMessage">
            <wsdl:part name="value" type="xsd:string"/>
          </wsdl:message>
          <wsdl:message name="OutputMessage">
            <wsdl:part name="value" type="xsd:string"/>
          </wsdl:message>
          <wsdl:portType name="FixturePortType">
            <wsdl:operation name="Transform">
              <wsdl:input message="tns:InputMessage"/>
              <wsdl:output message="tns:OutputMessage"/>
            </wsdl:operation>
          </wsdl:portType>
          <wsdl:binding name="FixtureBinding" type="tns:FixturePortType">
            <soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>
            <wsdl:operation name="Transform">
              <soap:operation soapAction="urn:transform" style="document"/>
              <wsdl:input><soap:body use="literal"/></wsdl:input>
              <wsdl:output><soap:body use="literal"/></wsdl:output>
            </wsdl:operation>
          </wsdl:binding>
          <wsdl:service name="FixtureService">
            <wsdl:port name="FixturePort" binding="tns:FixtureBinding"/>
          </wsdl:service>
        </wsdl:definitions>
        """
    }
}
