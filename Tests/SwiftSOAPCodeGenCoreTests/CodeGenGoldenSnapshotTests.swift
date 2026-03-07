import Foundation
import SwiftSOAPCodeGenCore
import XCTest

final class CodeGenGoldenSnapshotTests: XCTestCase {
    private let goldenFixtureExtension = "golden"

    private struct SoapMatrixCase {
        let id: String
        let namespaceURI: String
        let prefix: String
        let style: String
        let use: String
        let expectedVersion: String
    }

    private let matrixCases: [SoapMatrixCase] = [
        SoapMatrixCase(
            id: "doc-literal-soap11",
            namespaceURI: "http://schemas.xmlsoap.org/wsdl/soap/",
            prefix: "soap",
            style: "document",
            use: "literal",
            expectedVersion: "soap11"
        ),
        SoapMatrixCase(
            id: "doc-literal-soap12",
            namespaceURI: "http://schemas.xmlsoap.org/wsdl/soap12/",
            prefix: "soap12",
            style: "document",
            use: "literal",
            expectedVersion: "soap12"
        ),
        SoapMatrixCase(
            id: "rpc-literal-soap11",
            namespaceURI: "http://schemas.xmlsoap.org/wsdl/soap/",
            prefix: "soap",
            style: "rpc",
            use: "literal",
            expectedVersion: "soap11"
        ),
        SoapMatrixCase(
            id: "rpc-literal-soap12",
            namespaceURI: "http://schemas.xmlsoap.org/wsdl/soap12/",
            prefix: "soap12",
            style: "rpc",
            use: "literal",
            expectedVersion: "soap12"
        ),
        SoapMatrixCase(
            id: "rpc-encoded-soap11",
            namespaceURI: "http://schemas.xmlsoap.org/wsdl/soap/",
            prefix: "soap",
            style: "rpc",
            use: "encoded",
            expectedVersion: "soap11"
        ),
        SoapMatrixCase(
            id: "rpc-encoded-soap12",
            namespaceURI: "http://schemas.xmlsoap.org/wsdl/soap12/",
            prefix: "soap12",
            style: "rpc",
            use: "encoded",
            expectedVersion: "soap12"
        )
    ]

    func test_generate_bindingMatrix_matchesGoldenSnapshots() throws {
        let shouldUpdateGolden = ProcessInfo.processInfo.environment["UPDATE_GOLDEN"] == "1"
        let fixtureDirectoryURL = try goldenFixtureDirectoryURL()
        if shouldUpdateGolden {
            try FileManager.default.createDirectory(at: fixtureDirectoryURL, withIntermediateDirectories: true)
        }

        for testCase in matrixCases {
            let generatedSource = try generateSource(for: testCase)
            XCTAssertTrue(generatedSource.contains("envelopeVersion: .\(testCase.expectedVersion)"))
            XCTAssertTrue(generatedSource.contains("style: .\(testCase.style)"))
            XCTAssertTrue(generatedSource.contains("bodyUse: .\(testCase.use)"))

            let fixtureFileURL = fixtureDirectoryURL.appendingPathComponent(
                "\(testCase.id).\(goldenFixtureExtension)"
            )
            if shouldUpdateGolden {
                try generatedSource.write(to: fixtureFileURL, atomically: true, encoding: .utf8)
                continue
            }

            guard FileManager.default.fileExists(atPath: fixtureFileURL.path) else {
                XCTFail("Missing golden fixture \(fixtureFileURL.path). Run with UPDATE_GOLDEN=1.")
                continue
            }

            let expectedSource = try String(contentsOf: fixtureFileURL, encoding: .utf8)
            XCTAssertEqual(normalizeSource(generatedSource), normalizeSource(expectedSource), "Mismatch for \(testCase.id)")
        }
    }

    func test_generatedSources_compileInFixturePackage() throws {
        let rootPath = FileManager.default.currentDirectoryPath
        let fixtureRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("swift-soap-codegen-compile-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let packageManifest = makeCompileFixtureManifest(rootPath: rootPath)
        try packageManifest.write(
            to: fixtureRoot.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        for testCase in matrixCases {
            let generatedSource = try generateSource(for: testCase)
            let targetName = targetName(for: testCase)
            let targetDirectory = fixtureRoot.appendingPathComponent("Sources/\(targetName)", isDirectory: true)
            try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
            try generatedSource.write(
                to: targetDirectory.appendingPathComponent("Generated.swift"),
                atomically: true,
                encoding: .utf8
            )
        }

        try runProcess(
            launchPath: "/usr/bin/env",
            arguments: ["swift", "build", "--package-path", fixtureRoot.path],
            currentDirectoryPath: fixtureRoot.path
        )
    }

    private func generateSource(for testCase: SoapMatrixCase) throws -> String {
        let wsdl = makeWSDL(
            soapNamespaceURI: testCase.namespaceURI,
            soapPrefix: testCase.prefix,
            style: testCase.style,
            use: testCase.use
        )

        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let wsdlURL = tempDirectory.appendingPathComponent("service.wsdl")
        try wsdl.write(to: wsdlURL, atomically: true, encoding: .utf8)

        let configuration = CodeGenConfiguration(
            wsdlPath: wsdlURL.path,
            moduleName: moduleName(for: testCase),
            outputMode: .build,
            runtimeTargets: [.async],
            generationScope: [.client, .server],
            targetSwiftVersion: SwiftLanguageVersion(major: 6, minor: 0)
        )

        let generator = CodeGenerator()
        let artifacts = try generator.generate(configuration: configuration)
        return try XCTUnwrap(artifacts.first?.contents)
    }

    private func makeCompileFixtureManifest(rootPath: String) -> String {
        let escapedRoot = rootPath.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let targetDefinitions = matrixCases.map { testCase in
            let target = targetName(for: testCase)
            return """
                    .target(
                        name: "\(target)",
                        dependencies: [
                            .product(name: "SwiftSOAPCore", package: "swift-soap"),
                            .product(name: "SwiftSOAPClientAsync", package: "swift-soap"),
                            .product(name: "SwiftSOAPServerAsync", package: "swift-soap")
                        ]
                    )
            """
        }.joined(separator: ",\n")

        return """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "GeneratedCompileFixture",
            platforms: [
                .macOS(.v10_15)
            ],
            dependencies: [
                .package(path: "\(escapedRoot)")
            ],
            targets: [
        \(targetDefinitions)
            ]
        )
        """
    }

    private func goldenFixtureDirectoryURL() throws -> URL {
        let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        return rootURL.appendingPathComponent("Tests/SwiftSOAPCodeGenCoreTests/Fixtures/Golden", isDirectory: true)
    }

    private func normalizeSource(_ source: String) -> String {
        source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func targetName(for testCase: SoapMatrixCase) -> String {
        "Generated\(moduleName(for: testCase))"
    }

    private func moduleName(for testCase: SoapMatrixCase) -> String {
        let components = testCase.id
            .split(separator: "-")
            .map { component in
                component.prefix(1).uppercased() + component.dropFirst()
            }
        return "Golden" + components.joined()
    }

    private func runProcess(
        launchPath: String,
        arguments: [String],
        currentDirectoryPath: String
    ) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? "<unable to decode process output>"
            XCTFail("Command failed: \(launchPath) \(arguments.joined(separator: " "))\n\(output)")
        }
    }

    private func makeWSDL(
        soapNamespaceURI: String,
        soapPrefix: String,
        style: String,
        use: String
    ) -> String {
        """
        <wsdl:definitions
            xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
            xmlns:\(soapPrefix)="\(soapNamespaceURI)"
            xmlns:tns="urn:matrix"
            xmlns:xsd="http://www.w3.org/2001/XMLSchema"
            targetNamespace="urn:matrix"
            name="MatrixService">
          <wsdl:types>
            <xsd:schema targetNamespace="urn:matrix">
              <xsd:complexType name="MatrixPayload">
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
          <wsdl:message name="FaultMessage">
            <wsdl:part name="reason" type="xsd:string"/>
          </wsdl:message>
          <wsdl:portType name="MatrixPortType">
            <wsdl:operation name="Transform">
              <wsdl:input message="tns:InputMessage"/>
              <wsdl:output message="tns:OutputMessage"/>
              <wsdl:fault name="Fault" message="tns:FaultMessage"/>
            </wsdl:operation>
          </wsdl:portType>
          <wsdl:binding name="MatrixBinding" type="tns:MatrixPortType">
            <\(soapPrefix):binding style="\(style)" transport="http://schemas.xmlsoap.org/soap/http"/>
            <wsdl:operation name="Transform">
              <\(soapPrefix):operation soapAction="urn:transform" style="\(style)"/>
              <wsdl:input><\(soapPrefix):body use="\(use)"/></wsdl:input>
              <wsdl:output><\(soapPrefix):body use="\(use)"/></wsdl:output>
            </wsdl:operation>
          </wsdl:binding>
          <wsdl:service name="MatrixService">
            <wsdl:port name="MatrixPort" binding="tns:MatrixBinding"/>
          </wsdl:service>
        </wsdl:definitions>
        """
    }
}
