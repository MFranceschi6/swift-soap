import Foundation
import SwiftSOAPCodeGenCore
import SwiftSOAPWSDL
import XCTest

final class CodeGenPipelineTests: XCTestCase {
    private struct SoapMatrixCase {
        let namespaceURI: String
        let prefix: String
        let style: String
        let use: String
        let expectedVersion: String
    }

    func test_configurationDecoder_appliesCLIOverrides() throws {
        let json = """
        {
          "wsdlPath": "Fixtures/service.wsdl",
          "moduleName": "Weather",
          "outputMode": "build",
          "buildOutputDirectory": ".build/generated",
          "exportOutputDirectory": "Sources/Generated",
          "runtimeTargets": ["async"],
          "generationScope": ["client"],
          "targetSwiftVersion": "6.0",
          "syntaxFeatures": {
            "typedThrowsAnyError": false
          }
        }
        """

        let decoder = JSONCodeGenConfigurationDecoder()
        var configuration = try decoder.decode(data: Data(json.utf8))

        var overrides = CodeGenConfigurationOverrides()
        overrides.moduleName = "WeatherAdvanced"
        overrides.outputMode = .both
        overrides.runtimeTargets = [.async, .nio]
        overrides.generationScope = [.client, .server]
        configuration.apply(overrides: overrides)

        XCTAssertEqual(configuration.moduleName, "WeatherAdvanced")
        XCTAssertEqual(configuration.outputMode, .both)
        XCTAssertEqual(configuration.runtimeTargets, [.async, .nio])
        XCTAssertEqual(configuration.generationScope, [.client, .server])
        XCTAssertEqual(configuration.targetSwiftVersion, SwiftLanguageVersion(major: 6, minor: 0))
        XCTAssertEqual(configuration.syntaxFeatures["typedThrowsAnyError"], false)
    }

    func test_irBuilder_withUnresolvedBinding_throwsDiagnosticCode() throws {
        let definition = WSDLDefinition(
            name: "Invalid",
            targetNamespace: "urn:test",
            messages: [
                WSDLDefinition.Message(name: "Input", parts: []),
                WSDLDefinition.Message(name: "Output", parts: [])
            ],
            portTypes: [
                WSDLDefinition.PortType(
                    name: "PortType",
                    operations: [
                        WSDLDefinition.Operation(
                            name: "Op",
                            inputMessageName: "Input",
                            outputMessageName: "Output",
                            faults: []
                        )
                    ]
                )
            ],
            bindings: [],
            services: [
                WSDLDefinition.Service(
                    name: "Service",
                    ports: [WSDLDefinition.ServicePort(name: "Port", bindingName: "MissingBinding", address: nil)]
                )
            ]
        )

        let configuration = CodeGenConfiguration(
            wsdlPath: "ignored.wsdl",
            moduleName: "Invalid",
            outputMode: .build,
            runtimeTargets: [.async],
            generationScope: [.client],
            targetSwiftVersion: SwiftLanguageVersion(major: 6, minor: 0)
        )

        let builder = CodeGenerationIRBuilder()
        XCTAssertThrowsError(try builder.build(from: definition, configuration: configuration)) { error in
            guard let codeGenError = error as? CodeGenError else {
                return XCTFail("Expected CodeGenError, got \(error)")
            }
            XCTAssertEqual(codeGenError.code, .unresolvedReference)
        }
    }

    func test_generate_withSoapBindingMatrix_emitsBindingMetadataForAllVariants() throws {
        let matrix: [SoapMatrixCase] = [
            SoapMatrixCase(
                namespaceURI: "http://schemas.xmlsoap.org/wsdl/soap/",
                prefix: "soap",
                style: "document",
                use: "literal",
                expectedVersion: "soap11"
            ),
            SoapMatrixCase(
                namespaceURI: "http://schemas.xmlsoap.org/wsdl/soap12/",
                prefix: "soap12",
                style: "document",
                use: "literal",
                expectedVersion: "soap12"
            ),
            SoapMatrixCase(
                namespaceURI: "http://schemas.xmlsoap.org/wsdl/soap/",
                prefix: "soap",
                style: "rpc",
                use: "literal",
                expectedVersion: "soap11"
            ),
            SoapMatrixCase(
                namespaceURI: "http://schemas.xmlsoap.org/wsdl/soap12/",
                prefix: "soap12",
                style: "rpc",
                use: "literal",
                expectedVersion: "soap12"
            ),
            SoapMatrixCase(
                namespaceURI: "http://schemas.xmlsoap.org/wsdl/soap/",
                prefix: "soap",
                style: "rpc",
                use: "encoded",
                expectedVersion: "soap11"
            ),
            SoapMatrixCase(
                namespaceURI: "http://schemas.xmlsoap.org/wsdl/soap12/",
                prefix: "soap12",
                style: "rpc",
                use: "encoded",
                expectedVersion: "soap12"
            )
        ]

        for testCase in matrix {
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
                moduleName: "SoapMatrix",
                outputMode: .build,
                buildOutputDirectory: tempDirectory.appendingPathComponent("build").path,
                exportOutputDirectory: tempDirectory.appendingPathComponent("export").path,
                runtimeTargets: [.async, .nio],
                generationScope: [.client, .server],
                targetSwiftVersion: SwiftLanguageVersion(major: 6, minor: 0)
            )

            let generator = CodeGenerator()
            let artifacts = try generator.generate(configuration: configuration)
            let generatedSource = artifacts.map(\.contents).joined(separator: "\n")

            XCTAssertTrue(generatedSource.contains("envelopeVersion: .\(testCase.expectedVersion)"))
            XCTAssertTrue(generatedSource.contains("style: .\(testCase.style)"))
            XCTAssertTrue(generatedSource.contains("bodyUse: .\(testCase.use)"))
            XCTAssertTrue(generatedSource.contains("AsyncClient"))
            XCTAssertTrue(generatedSource.contains("NIOClient"))
            XCTAssertTrue(generatedSource.contains("AsyncServerRegistrar"))
            XCTAssertTrue(generatedSource.contains("NIOServerRegistrar"))
        }
    }

    func test_generator_writeArtifacts_withOutputModeBoth_writesBuildAndExport() throws {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let wsdlURL = tempDirectory.appendingPathComponent("service.wsdl")
        try makeWSDL(
            soapNamespaceURI: "http://schemas.xmlsoap.org/wsdl/soap/",
            soapPrefix: "soap",
            style: "document",
            use: "literal"
        ).write(to: wsdlURL, atomically: true, encoding: .utf8)

        let buildDirectory = tempDirectory.appendingPathComponent(".build/generated")
        let exportDirectory = tempDirectory.appendingPathComponent("Sources/Generated")

        let configuration = CodeGenConfiguration(
            wsdlPath: wsdlURL.path,
            moduleName: "DualOutput",
            outputMode: .both,
            buildOutputDirectory: buildDirectory.path,
            exportOutputDirectory: exportDirectory.path,
            runtimeTargets: [.async],
            generationScope: [.client],
            targetSwiftVersion: SwiftLanguageVersion(major: 6, minor: 0)
        )

        let generator = CodeGenerator()
        let artifacts = try generator.generate(configuration: configuration)
        try generator.writeArtifacts(artifacts, configuration: configuration)

        let generatedFileName = try XCTUnwrap(artifacts.first?.fileName)
        let buildFileURL = buildDirectory.appendingPathComponent(generatedFileName)
        let exportFileURL = exportDirectory.appendingPathComponent(generatedFileName)

        XCTAssertTrue(FileManager.default.fileExists(atPath: buildFileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportFileURL.path))
    }

    func test_generate_withSyntaxOverrides_changesPublicMethodSyntax() throws {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let wsdlURL = tempDirectory.appendingPathComponent("service.wsdl")
        try makeWSDL(
            soapNamespaceURI: "http://schemas.xmlsoap.org/wsdl/soap/",
            soapPrefix: "soap",
            style: "document",
            use: "literal"
        ).write(to: wsdlURL, atomically: true, encoding: .utf8)

        let configuration = CodeGenConfiguration(
            wsdlPath: wsdlURL.path,
            moduleName: "SyntaxOverrides",
            outputMode: .build,
            runtimeTargets: [.async],
            generationScope: [.client, .server],
            targetSwiftVersion: SwiftLanguageVersion(major: 6, minor: 0),
            syntaxFeatures: ["typedThrowsAnyError": false]
        )

        let generator = CodeGenerator()
        let artifacts = try generator.generate(configuration: configuration)
        let generatedSource = artifacts.map(\.contents).joined(separator: "\n")

        XCTAssertTrue(generatedSource.contains("public let client: any SOAPClientAsync"))
        XCTAssertTrue(generatedSource.contains("async throws -> SOAPOperationResponse"))
        XCTAssertFalse(generatedSource.contains("throws(any Error)"))
    }

    func test_resolvedSyntaxProfile_withSwift6AndTypedThrowsDisabled_usesFallbackThrows() throws {
        let configuration = CodeGenConfiguration(
            wsdlPath: "ignored.wsdl",
            moduleName: "FeatureGates",
            runtimeTargets: [.async],
            generationScope: [.client],
            targetSwiftVersion: SwiftLanguageVersion(major: 6, minor: 0),
            syntaxFeatures: ["typedThrowsAnyError": false]
        )

        let profile = try configuration.resolvedSyntaxProfile()
        XCTAssertTrue(profile.useExistentialAny)
        XCTAssertFalse(profile.useTypedThrowsAnyError)
    }

    func test_resolvedSyntaxProfile_withSwift6AndExistentialAnyDisabled_throwsInvalidSyntaxFeature() {
        let configuration = CodeGenConfiguration(
            wsdlPath: "ignored.wsdl",
            moduleName: "FeatureGates",
            runtimeTargets: [.async],
            generationScope: [.client],
            targetSwiftVersion: SwiftLanguageVersion(major: 6, minor: 0),
            syntaxFeatures: ["existentialAny": false]
        )

        XCTAssertThrowsError(try configuration.resolvedSyntaxProfile()) { error in
            guard let codeGenError = error as? CodeGenError else {
                return XCTFail("Expected CodeGenError, got \(error)")
            }
            XCTAssertEqual(codeGenError.code, .invalidSyntaxFeature)
        }
    }

    func test_resolvedSyntaxProfile_withSwift54AndAsyncTarget_throwsUnsupportedSwiftTarget() {
        let configuration = CodeGenConfiguration(
            wsdlPath: "ignored.wsdl",
            moduleName: "FeatureGates",
            runtimeTargets: [.async],
            generationScope: [.client],
            targetSwiftVersion: SwiftLanguageVersion(major: 5, minor: 4)
        )

        XCTAssertThrowsError(try configuration.resolvedSyntaxProfile()) { error in
            guard let codeGenError = error as? CodeGenError else {
                return XCTFail("Expected CodeGenError, got \(error)")
            }
            XCTAssertEqual(codeGenError.code, .unsupportedSwiftTarget)
        }
    }

    func test_generate_withExternalXSDImport_resolvesTypesFromImportedSchema() throws {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let xsd = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xsd:schema targetNamespace="urn:weather"
                    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:complexType name="WeatherRequest">
            <xsd:sequence>
              <xsd:element name="city" type="xsd:string"/>
            </xsd:sequence>
          </xsd:complexType>
          <xsd:complexType name="WeatherResponse">
            <xsd:sequence>
              <xsd:element name="temperature" type="xsd:string"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """

        let wsdl = """
        <wsdl:definitions
            xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
            xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
            xmlns:tns="urn:weather"
            xmlns:xsd="http://www.w3.org/2001/XMLSchema"
            targetNamespace="urn:weather"
            name="WeatherService">
          <wsdl:types>
            <xsd:schema targetNamespace="urn:weather">
              <xsd:import namespace="urn:weather" schemaLocation="types.xsd"/>
            </xsd:schema>
          </wsdl:types>
          <wsdl:message name="GetWeatherInput">
            <wsdl:part name="parameters" type="tns:WeatherRequest"/>
          </wsdl:message>
          <wsdl:message name="GetWeatherOutput">
            <wsdl:part name="parameters" type="tns:WeatherResponse"/>
          </wsdl:message>
          <wsdl:portType name="WeatherPortType">
            <wsdl:operation name="GetWeather">
              <wsdl:input message="tns:GetWeatherInput"/>
              <wsdl:output message="tns:GetWeatherOutput"/>
            </wsdl:operation>
          </wsdl:portType>
          <wsdl:binding name="WeatherBinding" type="tns:WeatherPortType">
            <soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>
            <wsdl:operation name="GetWeather">
              <soap:operation soapAction="urn:GetWeather" style="document"/>
              <wsdl:input><soap:body use="literal"/></wsdl:input>
              <wsdl:output><soap:body use="literal"/></wsdl:output>
            </wsdl:operation>
          </wsdl:binding>
          <wsdl:service name="WeatherService">
            <wsdl:port name="WeatherPort" binding="tns:WeatherBinding"/>
          </wsdl:service>
        </wsdl:definitions>
        """

        let xsdURL = tempDirectory.appendingPathComponent("types.xsd")
        let wsdlURL = tempDirectory.appendingPathComponent("service.wsdl")
        try xsd.write(to: xsdURL, atomically: true, encoding: .utf8)
        try wsdl.write(to: wsdlURL, atomically: true, encoding: .utf8)

        let configuration = CodeGenConfiguration(
            wsdlPath: wsdlURL.path,
            moduleName: "Weather",
            outputMode: .build,
            runtimeTargets: [.async],
            generationScope: [.client],
            targetSwiftVersion: SwiftLanguageVersion(major: 6, minor: 0)
        )

        let generator = CodeGenerator()
        let artifacts = try generator.generate(configuration: configuration)
        let generatedSource = artifacts.map(\.contents).joined(separator: "\n")

        // Types from the imported XSD must appear in generated output
        XCTAssertTrue(generatedSource.contains("WeatherRequest"), "Expected WeatherRequest type from imported XSD")
        XCTAssertTrue(generatedSource.contains("WeatherResponse"), "Expected WeatherResponse type from imported XSD")
        XCTAssertTrue(generatedSource.contains("city"), "Expected 'city' field from WeatherRequest")
        XCTAssertTrue(generatedSource.contains("temperature"), "Expected 'temperature' field from WeatherResponse")
        XCTAssertTrue(generatedSource.contains("WeatherServiceWeatherPortAsyncClient"))
    }

    private func makeWSDL(
        soapNamespaceURI: String,
        soapPrefix: String,
        style: String,
        use: String
    ) -> String {
        return """
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
