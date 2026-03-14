import Foundation
import SwiftSOAPCodeGenCore
import SwiftSOAPWSDL
import XCTest

/// Tests for XML-6.10C/D: enumeration IR, facet constraints, CodingKeys emission, required fix.
final class SemanticValidationIRTests: XCTestCase {

    // MARK: - GeneratedTypeKind.enumeration

    func test_irBuilder_simpleTypeWithEnumeration_generatesEnumerationKind() throws {
        let wsdl = makeWSDL(withTypes: """
        <xsd:simpleType name="Priority">
          <xsd:restriction base="xsd:string">
            <xsd:enumeration value="low"/>
            <xsd:enumeration value="medium"/>
            <xsd:enumeration value="high"/>
          </xsd:restriction>
        </xsd:simpleType>
        """)

        let ir = try buildIR(from: wsdl)
        let priorityType = try XCTUnwrap(ir.generatedTypes.first(where: { $0.swiftTypeName == "Priority" }))
        XCTAssertEqual(priorityType.kind, .enumeration)
        XCTAssertEqual(priorityType.enumerationCases, ["low", "medium", "high"])
        XCTAssertTrue(priorityType.fields.isEmpty)
    }

    func test_irBuilder_simpleTypeWithoutEnumeration_generatesSchemaModel() throws {
        let wsdl = makeWSDL(withTypes: """
        <xsd:simpleType name="PostalCode">
          <xsd:restriction base="xsd:string">
            <xsd:minLength value="4"/>
            <xsd:maxLength value="6"/>
          </xsd:restriction>
        </xsd:simpleType>
        """)

        let ir = try buildIR(from: wsdl)
        let postalCodeType = try XCTUnwrap(ir.generatedTypes.first(where: { $0.swiftTypeName == "PostalCode" }))
        XCTAssertEqual(postalCodeType.kind, .schemaModel)
        let rawValueField = try XCTUnwrap(postalCodeType.fields.first)
        let minLengthConstraint = rawValueField.constraints.first(where: { $0.kind == .minLength })
        let maxLengthConstraint = rawValueField.constraints.first(where: { $0.kind == .maxLength })
        XCTAssertNotNil(minLengthConstraint)
        XCTAssertEqual(minLengthConstraint?.value, "4")
        XCTAssertNotNil(maxLengthConstraint)
        XCTAssertEqual(maxLengthConstraint?.value, "6")
    }

    // MARK: - Emitter: enum type emission

    func test_emitter_enumerationKind_emitsSwiftEnum() throws {
        let ir = SOAPCodeGenerationIR(
            moduleName: "Test",
            generationScope: [.client],
            runtimeTargets: [.async],
            generatedTypes: [
                GeneratedTypeIR(
                    swiftTypeName: "Status",
                    kind: .enumeration,
                    fields: [],
                    enumerationCases: ["active", "inactive", "pending"]
                )
            ],
            services: []
        )
        let profile = CodeGenerationSyntaxProfile(
            targetSwiftVersion: SwiftLanguageVersion(major: 5, minor: 9),
            useExistentialAny: false,
            useTypedThrowsAnyError: false
        )
        let emitter = SwiftCodeEmitter()
        let output = emitter.emit(ir: ir, syntaxProfile: profile).map(\.contents).joined(separator: "\n")

        XCTAssertTrue(output.contains("public enum Status: String, Codable, Sendable, Equatable {"))
        XCTAssertTrue(output.contains("case active"))
        XCTAssertTrue(output.contains("case inactive"))
        XCTAssertTrue(output.contains("case pending"))
        XCTAssertFalse(output.contains("public struct Status"))
    }

    // MARK: - Emitter: CodingKeys emission when xmlName differs

    func test_emitter_fieldWithDifferentXmlName_emitsCodingKeys() {
        let ir = SOAPCodeGenerationIR(
            moduleName: "Test",
            generationScope: [.client],
            runtimeTargets: [.async],
            generatedTypes: [
                GeneratedTypeIR(
                    swiftTypeName: "Payload",
                    kind: .schemaModel,
                    fields: [
                        GeneratedTypeFieldIR(
                            name: "firstName",
                            swiftTypeName: "String",
                            isOptional: false,
                            xmlName: "first-name"
                        )
                    ]
                )
            ],
            services: []
        )
        let profile = CodeGenerationSyntaxProfile(
            targetSwiftVersion: SwiftLanguageVersion(major: 5, minor: 9),
            useExistentialAny: false,
            useTypedThrowsAnyError: false
        )
        let emitter = SwiftCodeEmitter()
        let output = emitter.emit(ir: ir, syntaxProfile: profile).map(\.contents).joined(separator: "\n")

        XCTAssertTrue(output.contains("enum CodingKeys: String, CodingKey {"))
        XCTAssertTrue(output.contains("case firstName = \"first-name\""))
    }

    // MARK: - Emitter: validate() emission for strict profile with constraints

    func test_emitter_strictProfile_withConstraints_emitsValidateMethod() {
        let ir = SOAPCodeGenerationIR(
            moduleName: "Test",
            generationScope: [.client],
            runtimeTargets: [.async],
            generatedTypes: [
                GeneratedTypeIR(
                    swiftTypeName: "ZipCode",
                    kind: .schemaModel,
                    fields: [
                        GeneratedTypeFieldIR(
                            name: "rawValue",
                            swiftTypeName: "String",
                            isOptional: false,
                            constraints: [
                                FacetConstraintIR(kind: .minLength, value: "5"),
                                FacetConstraintIR(kind: .maxLength, value: "5")
                            ]
                        )
                    ],
                    enumerationCases: []
                )
            ],
            services: [],
            validationProfile: .strict
        )
        let profile = CodeGenerationSyntaxProfile(
            targetSwiftVersion: SwiftLanguageVersion(major: 5, minor: 9),
            useExistentialAny: false,
            useTypedThrowsAnyError: false
        )
        let emitter = SwiftCodeEmitter()
        let output = emitter.emit(ir: ir, syntaxProfile: profile).map(\.contents).joined(separator: "\n")

        XCTAssertTrue(output.contains("public func validate() throws {"))
    }

    func test_emitter_repeatedArrayField_emitsOccurrenceValidation() {
        let ir = SOAPCodeGenerationIR(
            moduleName: "Test",
            generationScope: [.client],
            runtimeTargets: [.async],
            generatedTypes: [
                GeneratedTypeIR(
                    swiftTypeName: "Inventory",
                    kind: .schemaModel,
                    fields: [
                        GeneratedTypeFieldIR(
                            name: "codes",
                            swiftTypeName: "[String]",
                            isOptional: false,
                            minOccurs: 2,
                            maxOccurs: 4
                        ),
                        GeneratedTypeFieldIR(
                            name: "exactlyThree",
                            swiftTypeName: "[String]",
                            isOptional: false,
                            minOccurs: 3,
                            maxOccurs: 3
                        ),
                        GeneratedTypeFieldIR(
                            name: "aliases",
                            swiftTypeName: "[String]",
                            isOptional: true,
                            minOccurs: 0,
                            maxOccurs: 3
                        )
                    ]
                )
            ],
            services: [],
            validationProfile: .strict
        )
        let profile = CodeGenerationSyntaxProfile(
            targetSwiftVersion: SwiftLanguageVersion(major: 5, minor: 9),
            useExistentialAny: false,
            useTypedThrowsAnyError: false
        )
        let emitter = SwiftCodeEmitter()
        let output = emitter.emit(ir: ir, syntaxProfile: profile).map(\.contents).joined(separator: "\n")

        XCTAssertTrue(output.contains("if codes.count < 2 {"))
        XCTAssertTrue(output.contains("if codes.count > 4 {"))
        XCTAssertTrue(output.contains("if exactlyThree.count != 3 {"))
        XCTAssertTrue(output.contains("if let value = aliases {"))
        XCTAssertTrue(output.contains("if value.count > 3 {"))
        XCTAssertTrue(output.contains("[CG_SEMANTIC_005]"))
        XCTAssertTrue(output.contains("[CG_SEMANTIC_006]"))
        XCTAssertTrue(output.contains("[CG_SEMANTIC_007]"))
    }

    func test_emitter_lenientProfile_withConstraints_doesNotEmitValidateMethod() {
        let ir = SOAPCodeGenerationIR(
            moduleName: "Test",
            generationScope: [.client],
            runtimeTargets: [.async],
            generatedTypes: [
                GeneratedTypeIR(
                    swiftTypeName: "ZipCode",
                    kind: .schemaModel,
                    fields: [
                        GeneratedTypeFieldIR(
                            name: "rawValue",
                            swiftTypeName: "String",
                            isOptional: false,
                            constraints: [FacetConstraintIR(kind: .minLength, value: "5")]
                        )
                    ]
                )
            ],
            services: [],
            validationProfile: .lenient
        )
        let profile = CodeGenerationSyntaxProfile(
            targetSwiftVersion: SwiftLanguageVersion(major: 5, minor: 9),
            useExistentialAny: false,
            useTypedThrowsAnyError: false
        )
        let emitter = SwiftCodeEmitter()
        let output = emitter.emit(ir: ir, syntaxProfile: profile).map(\.contents).joined(separator: "\n")

        XCTAssertFalse(output.contains("public func validate() throws {"))
    }

    // MARK: - XSD required fix: minOccurs absent → non-optional

    func test_irBuilder_complexTypeWithNoMinOccurs_generatesNonOptionalField() throws {
        let wsdl = makeWSDL(withTypes: """
        <xsd:complexType name="Address">
          <xsd:sequence>
            <xsd:element name="street" type="xsd:string"/>
            <xsd:element name="city" type="xsd:string" minOccurs="0"/>
          </xsd:sequence>
        </xsd:complexType>
        """)

        let ir = try buildIR(from: wsdl)
        let addressType = try XCTUnwrap(ir.generatedTypes.first(where: { $0.swiftTypeName == "Address" }))

        let streetField = try XCTUnwrap(addressType.fields.first(where: { $0.name == "street" }))
        let cityField = try XCTUnwrap(addressType.fields.first(where: { $0.name == "city" }))

        XCTAssertFalse(streetField.isOptional, "street has no minOccurs → required (non-optional)")
        XCTAssertTrue(cityField.isOptional, "city has minOccurs=0 → optional")
    }

    func test_irBuilder_repeatedElement_preservesOccurrenceBoundsForArrayValidation() throws {
        let wsdl = makeWSDL(withTypes: """
        <xsd:complexType name="Inventory">
          <xsd:sequence>
            <xsd:element name="codes" type="xsd:string" minOccurs="2" maxOccurs="4"/>
            <xsd:element name="aliases" type="xsd:string" minOccurs="0" maxOccurs="3"/>
          </xsd:sequence>
        </xsd:complexType>
        """)

        let ir = try buildIR(from: wsdl)
        let inventoryType = try XCTUnwrap(
            ir.generatedTypes.first(where: { $0.swiftTypeName == "Inventory" })
        )

        let codesField = try XCTUnwrap(inventoryType.fields.first(where: { $0.name == "codes" }))
        XCTAssertEqual(codesField.swiftTypeName, "[String]")
        XCTAssertFalse(codesField.isOptional)
        XCTAssertEqual(codesField.minOccurs, 2)
        XCTAssertEqual(codesField.maxOccurs, 4)

        let aliasesField = try XCTUnwrap(inventoryType.fields.first(where: { $0.name == "aliases" }))
        XCTAssertEqual(aliasesField.swiftTypeName, "[String]")
        XCTAssertTrue(aliasesField.isOptional)
        XCTAssertEqual(aliasesField.minOccurs, 0)
        XCTAssertEqual(aliasesField.maxOccurs, 3)
    }

    func test_irBuilder_documentLiteralNamedWrapper_resolvesNamedComplexTypeAndFlattensExtensions() throws {
        let wsdl = makeDocumentLiteralWSDL(withTypes: """
        <xsd:element name="PerformAction" type="tns:PerformActionType"/>
        <xsd:complexType name="PerformActionType">
          <xsd:sequence>
            <xsd:element name="request" type="tns:ExtendedRequest" minOccurs="0"/>
          </xsd:sequence>
        </xsd:complexType>
        <xsd:complexType name="BaseRequest">
          <xsd:sequence>
            <xsd:element name="tag" type="xsd:string"/>
          </xsd:sequence>
        </xsd:complexType>
        <xsd:complexType name="ExtendedRequest">
          <xsd:complexContent>
            <xsd:extension base="tns:BaseRequest">
              <xsd:sequence>
                <xsd:element name="details" type="xsd:string"/>
                <xsd:element name="items" type="xsd:string" minOccurs="0" maxOccurs="unbounded"/>
              </xsd:sequence>
            </xsd:extension>
          </xsd:complexContent>
        </xsd:complexType>
        <xsd:element name="PerformActionResponse" type="tns:PerformActionResponseType"/>
        <xsd:complexType name="PerformActionResponseType">
          <xsd:sequence>
            <xsd:element name="return" type="xsd:string" minOccurs="0"/>
          </xsd:sequence>
        </xsd:complexType>
        """)

        let ir = try buildIR(from: wsdl)

        let payloadType = try XCTUnwrap(
            ir.generatedTypes.first(where: { $0.swiftTypeName == "PerformActionInputPayload" })
        )
        XCTAssertEqual(payloadType.xmlRootElementName, "PerformAction")
        XCTAssertEqual(payloadType.xmlRootElementNamespaceURI, "urn:test")

        let requestField = try XCTUnwrap(payloadType.fields.first(where: { $0.name == "request" }))
        XCTAssertEqual(requestField.swiftTypeName, "ExtendedRequest")
        XCTAssertTrue(requestField.isOptional)

        let extendedRequestType = try XCTUnwrap(
            ir.generatedTypes.first(where: { $0.swiftTypeName == "ExtendedRequest" })
        )
        XCTAssertEqual(extendedRequestType.fields.map(\.name), ["tag", "details", "items"])

        let tagField = try XCTUnwrap(extendedRequestType.fields.first(where: { $0.name == "tag" }))
        let itemsField = try XCTUnwrap(extendedRequestType.fields.first(where: { $0.name == "items" }))
        XCTAssertFalse(tagField.isOptional)
        XCTAssertEqual(itemsField.swiftTypeName, "[String]")
        XCTAssertTrue(itemsField.isOptional)
    }

    func test_irBuilder_complexTypeExtension_generatesProtocolHierarchy() throws {
        let wsdl = makeDocumentLiteralWSDL(withTypes: """
        <xsd:element name="PerformAction" type="tns:PerformActionType"/>
        <xsd:complexType name="PerformActionType">
          <xsd:sequence>
            <xsd:element name="request" type="tns:ExtendedRequest" minOccurs="0"/>
          </xsd:sequence>
        </xsd:complexType>
        <xsd:complexType name="BaseRequest">
          <xsd:sequence>
            <xsd:element name="tag" type="xsd:string"/>
          </xsd:sequence>
        </xsd:complexType>
        <xsd:complexType name="ExtendedRequest">
          <xsd:complexContent>
            <xsd:extension base="tns:BaseRequest">
              <xsd:sequence>
                <xsd:element name="details" type="xsd:string"/>
                <xsd:element name="items" type="xsd:string" minOccurs="0" maxOccurs="unbounded"/>
              </xsd:sequence>
            </xsd:extension>
          </xsd:complexContent>
        </xsd:complexType>
        <xsd:element name="PerformActionResponse" type="tns:PerformActionResponseType"/>
        <xsd:complexType name="PerformActionResponseType">
          <xsd:sequence>
            <xsd:element name="return" type="xsd:string" minOccurs="0"/>
          </xsd:sequence>
        </xsd:complexType>
        """)

        let ir = try buildIR(from: wsdl)

        let baseProtocol = try XCTUnwrap(
            ir.generatedProtocols.first(where: { $0.swiftTypeName == "BaseRequestProtocol" })
        )
        XCTAssertEqual(baseProtocol.inheritedProtocolNames, [])
        XCTAssertEqual(baseProtocol.fields.map(\.name), ["tag"])

        let extendedProtocol = try XCTUnwrap(
            ir.generatedProtocols.first(where: { $0.swiftTypeName == "ExtendedRequestProtocol" })
        )
        XCTAssertEqual(extendedProtocol.inheritedProtocolNames, ["BaseRequestProtocol"])
        XCTAssertEqual(extendedProtocol.fields.map(\.name), ["details", "items"])

        let extendedRequestType = try XCTUnwrap(
            ir.generatedTypes.first(where: { $0.swiftTypeName == "ExtendedRequest" })
        )
        XCTAssertEqual(extendedRequestType.protocolConformances, ["ExtendedRequestProtocol"])
    }

    func test_emitter_reservedSwiftKeywordField_isEscaped() throws {
        let wsdl = makeDocumentLiteralWSDL(withTypes: """
        <xsd:element name="PerformAction" type="tns:PerformActionType"/>
        <xsd:complexType name="PerformActionType">
          <xsd:sequence>
            <xsd:element name="request" type="xsd:string" minOccurs="0"/>
          </xsd:sequence>
        </xsd:complexType>
        <xsd:element name="PerformActionResponse" type="tns:PerformActionResponseType"/>
        <xsd:complexType name="PerformActionResponseType">
          <xsd:sequence>
            <xsd:element name="return" type="xsd:string" minOccurs="0"/>
          </xsd:sequence>
        </xsd:complexType>
        """)

        let output = try buildSource(from: wsdl)

        XCTAssertTrue(output.contains("public var `return`: String?"))
        XCTAssertTrue(output.contains("public init(`return`: String?)"))
        XCTAssertFalse(output.contains("public var return: String?"))
    }

    func test_emitter_complexTypeExtension_emitsProtocolFilesAndStructConformance() throws {
        let wsdl = makeDocumentLiteralWSDL(withTypes: """
        <xsd:element name="PerformAction" type="tns:PerformActionType"/>
        <xsd:complexType name="PerformActionType">
          <xsd:sequence>
            <xsd:element name="request" type="tns:ExtendedRequest" minOccurs="0"/>
          </xsd:sequence>
        </xsd:complexType>
        <xsd:complexType name="BaseRequest">
          <xsd:sequence>
            <xsd:element name="tag" type="xsd:string"/>
          </xsd:sequence>
        </xsd:complexType>
        <xsd:complexType name="ExtendedRequest">
          <xsd:complexContent>
            <xsd:extension base="tns:BaseRequest">
              <xsd:sequence>
                <xsd:element name="details" type="xsd:string"/>
                <xsd:element name="items" type="xsd:string" minOccurs="0" maxOccurs="unbounded"/>
              </xsd:sequence>
            </xsd:extension>
          </xsd:complexContent>
        </xsd:complexType>
        <xsd:element name="PerformActionResponse" type="tns:PerformActionResponseType"/>
        <xsd:complexType name="PerformActionResponseType">
          <xsd:sequence>
            <xsd:element name="return" type="xsd:string" minOccurs="0"/>
          </xsd:sequence>
        </xsd:complexType>
        """)

        let output = try buildSource(from: wsdl)

        XCTAssertTrue(output.contains("public protocol BaseRequestProtocol: Sendable {"))
        XCTAssertTrue(output.contains("var tag: String { get set }"))
        XCTAssertTrue(output.contains("public protocol ExtendedRequestProtocol: BaseRequestProtocol {"))
        XCTAssertTrue(output.contains("var details: String { get set }"))
        XCTAssertTrue(output.contains("var items: [String]? { get set }"))
        XCTAssertTrue(
            output.contains("public struct ExtendedRequest: Codable, Sendable, Equatable, ExtendedRequestProtocol {")
        )
    }

    // MARK: - ValidationProfile in CodeGenConfiguration

    func test_codeGenConfiguration_defaultValidationProfile_isStrict() {
        let config = CodeGenConfiguration(
            wsdlPath: "test.wsdl",
            moduleName: "Test",
            targetSwiftVersion: SwiftLanguageVersion(major: 5, minor: 9)
        )
        XCTAssertEqual(config.validationProfile, .strict)
    }

    func test_codeGenConfiguration_overrides_appliesValidationProfile() {
        var config = CodeGenConfiguration(
            wsdlPath: "test.wsdl",
            moduleName: "Test",
            targetSwiftVersion: SwiftLanguageVersion(major: 5, minor: 9)
        )
        var overrides = CodeGenConfigurationOverrides()
        overrides.validationProfile = .lenient
        config.apply(overrides: overrides)
        XCTAssertEqual(config.validationProfile, .lenient)
    }
}

// MARK: - Helpers

private func makeWSDL(withTypes types: String) -> String {
    """
    <wsdl:definitions
        xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
        xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
        xmlns:tns="urn:test"
        xmlns:xsd="http://www.w3.org/2001/XMLSchema"
        targetNamespace="urn:test"
        name="TestService">
      <wsdl:types>
        <xsd:schema targetNamespace="urn:test">
          \(types)
        </xsd:schema>
      </wsdl:types>
      <wsdl:message name="InputMessage">
        <wsdl:part name="value" type="xsd:string"/>
      </wsdl:message>
      <wsdl:message name="OutputMessage">
        <wsdl:part name="value" type="xsd:string"/>
      </wsdl:message>
      <wsdl:portType name="TestPortType">
        <wsdl:operation name="DoIt">
          <wsdl:input message="tns:InputMessage"/>
          <wsdl:output message="tns:OutputMessage"/>
        </wsdl:operation>
      </wsdl:portType>
      <wsdl:binding name="TestBinding" type="tns:TestPortType">
        <soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>
        <wsdl:operation name="DoIt">
          <soap:operation soapAction="urn:doIt" style="document"/>
          <wsdl:input><soap:body use="literal"/></wsdl:input>
          <wsdl:output><soap:body use="literal"/></wsdl:output>
        </wsdl:operation>
      </wsdl:binding>
      <wsdl:service name="TestService">
        <wsdl:port name="TestPort" binding="tns:TestBinding"/>
      </wsdl:service>
    </wsdl:definitions>
    """
}

private func makeDocumentLiteralWSDL(withTypes types: String) -> String {
    """
    <wsdl:definitions
        xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
        xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
        xmlns:tns="urn:test"
        xmlns:xsd="http://www.w3.org/2001/XMLSchema"
        targetNamespace="urn:test"
        name="TestService">
      <wsdl:types>
        <xsd:schema targetNamespace="urn:test">
          \(types)
        </xsd:schema>
      </wsdl:types>
      <wsdl:message name="PerformActionInput">
        <wsdl:part name="parameters" element="tns:PerformAction"/>
      </wsdl:message>
      <wsdl:message name="PerformActionOutput">
        <wsdl:part name="parameters" element="tns:PerformActionResponse"/>
      </wsdl:message>
      <wsdl:portType name="TestPortType">
        <wsdl:operation name="PerformAction">
          <wsdl:input message="tns:PerformActionInput"/>
          <wsdl:output message="tns:PerformActionOutput"/>
        </wsdl:operation>
      </wsdl:portType>
      <wsdl:binding name="TestBinding" type="tns:TestPortType">
        <soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>
        <wsdl:operation name="PerformAction">
          <soap:operation soapAction="urn:performAction" style="document"/>
          <wsdl:input><soap:body use="literal"/></wsdl:input>
          <wsdl:output><soap:body use="literal"/></wsdl:output>
        </wsdl:operation>
      </wsdl:binding>
      <wsdl:service name="TestService">
        <wsdl:port name="TestPort" binding="tns:TestBinding"/>
      </wsdl:service>
    </wsdl:definitions>
    """
}

private func buildIR(from wsdl: String) throws -> SOAPCodeGenerationIR {
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let wsdlURL = tempDir.appendingPathComponent("test.wsdl")
    try wsdl.write(to: wsdlURL, atomically: true, encoding: .utf8)

    let config = CodeGenConfiguration(
        wsdlPath: wsdlURL.path,
        moduleName: "Test",
        targetSwiftVersion: SwiftLanguageVersion(major: 5, minor: 9)
    )
    let parser = WSDLDocumentParser()
    let definition = try parser.parse(data: Data(wsdl.utf8))
    return try CodeGenerationIRBuilder().build(from: definition, configuration: config)
}

private func buildSource(from wsdl: String) throws -> String {
    let ir = try buildIR(from: wsdl)
    let emitter = SwiftCodeEmitter()
    let profile = CodeGenerationSyntaxProfile(
        targetSwiftVersion: SwiftLanguageVersion(major: 5, minor: 9),
        useExistentialAny: false,
        useTypedThrowsAnyError: false
    )
    return emitter.emit(ir: ir, syntaxProfile: profile).map(\.contents).joined(separator: "\n")
}
