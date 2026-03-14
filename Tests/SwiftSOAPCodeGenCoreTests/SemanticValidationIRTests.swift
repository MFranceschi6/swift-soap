import Foundation
import SwiftSOAPCodeGenCore
import SwiftSOAPWSDL
import XCTest
// swiftlint:disable type_body_length file_length

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

    func test_irBuilder_simpleTypeWithNumericFacets_preservesConstraints() throws {
        let wsdl = makeWSDL(withTypes: """
        <xsd:simpleType name="Price">
          <xsd:restriction base="xsd:decimal">
            <xsd:minInclusive value="1.25"/>
            <xsd:maxInclusive value="999.99"/>
            <xsd:minExclusive value="1.50"/>
            <xsd:maxExclusive value="999.50"/>
            <xsd:totalDigits value="5"/>
            <xsd:fractionDigits value="2"/>
          </xsd:restriction>
        </xsd:simpleType>
        """)

        let ir = try buildIR(from: wsdl)
        let priceType = try XCTUnwrap(ir.generatedTypes.first(where: { $0.swiftTypeName == "Price" }))
        let rawValueField = try XCTUnwrap(priceType.fields.first)

        XCTAssertEqual(rawValueField.swiftTypeName, "Double")
        XCTAssertEqual(rawValueField.constraints.first(where: { $0.kind == .minInclusive })?.value, "1.25")
        XCTAssertEqual(rawValueField.constraints.first(where: { $0.kind == .maxInclusive })?.value, "999.99")
        XCTAssertEqual(rawValueField.constraints.first(where: { $0.kind == .minExclusive })?.value, "1.50")
        XCTAssertEqual(rawValueField.constraints.first(where: { $0.kind == .maxExclusive })?.value, "999.50")
        XCTAssertEqual(rawValueField.constraints.first(where: { $0.kind == .totalDigits })?.value, "5")
        XCTAssertEqual(rawValueField.constraints.first(where: { $0.kind == .fractionDigits })?.value, "2")
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

    func test_emitter_choiceGroups_emitValidationChecks() {
        let ir = SOAPCodeGenerationIR(
            moduleName: "Test",
            generationScope: [.client],
            runtimeTargets: [.async],
            generatedTypes: [
                GeneratedTypeIR(
                    swiftTypeName: "Payment",
                    kind: .schemaModel,
                    fields: [
                        GeneratedTypeFieldIR(name: "cardNumber", swiftTypeName: "String", isOptional: true),
                        GeneratedTypeFieldIR(name: "iban", swiftTypeName: "String", isOptional: true),
                        GeneratedTypeFieldIR(name: "voucherCodes", swiftTypeName: "[String]", isOptional: true),
                        GeneratedTypeFieldIR(name: "couponCode", swiftTypeName: "String", isOptional: true)
                    ],
                    choiceGroups: [
                        GeneratedChoiceGroupIR(fieldNames: ["cardNumber", "iban"], minOccurs: 1, maxOccurs: 1),
                        GeneratedChoiceGroupIR(fieldNames: ["voucherCodes", "couponCode"], minOccurs: 0, maxOccurs: 1)
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

        XCTAssertTrue(output.contains("let choiceGroup0SelectionCount = (cardNumber != nil ? 1 : 0) + (iban != nil ? 1 : 0)"))
        XCTAssertTrue(output.contains("if choiceGroup0SelectionCount == 0 {"))
        XCTAssertTrue(output.contains("if choiceGroup0SelectionCount > 1 {"))
        XCTAssertTrue(output.contains("let choiceGroup1SelectionCount = (voucherCodes?.isEmpty == false ? 1 : 0) + (couponCode != nil ? 1 : 0)"))
        XCTAssertFalse(output.contains("if choiceGroup1SelectionCount == 0 {"))
        XCTAssertTrue(output.contains("if choiceGroup1SelectionCount > 1 {"))
        XCTAssertTrue(output.contains("[CG_SEMANTIC_012]"))
        XCTAssertTrue(output.contains("[CG_SEMANTIC_013]"))
    }

    func test_emitter_numericFacets_emitValidationChecks() {
        let ir = SOAPCodeGenerationIR(
            moduleName: "Test",
            generationScope: [.client],
            runtimeTargets: [.async],
            generatedTypes: [
                GeneratedTypeIR(
                    swiftTypeName: "Price",
                    kind: .schemaModel,
                    fields: [
                        GeneratedTypeFieldIR(
                            name: "rawValue",
                            swiftTypeName: "Double",
                            isOptional: false,
                            constraints: [
                                FacetConstraintIR(kind: .minInclusive, value: "1.25"),
                                FacetConstraintIR(kind: .maxInclusive, value: "999.99"),
                                FacetConstraintIR(kind: .minExclusive, value: "1.50"),
                                FacetConstraintIR(kind: .maxExclusive, value: "999.50"),
                                FacetConstraintIR(kind: .totalDigits, value: "5"),
                                FacetConstraintIR(kind: .fractionDigits, value: "2")
                            ]
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

        XCTAssertTrue(output.contains("if rawValue < 1.25 {"))
        XCTAssertTrue(output.contains("if rawValue > 999.99 {"))
        XCTAssertTrue(output.contains("if rawValue <= 1.50 {"))
        XCTAssertTrue(output.contains("if rawValue >= 999.50 {"))
        XCTAssertTrue(output.contains("let rawValueTotalDigitsSource = NSDecimalNumber(value: rawValue).stringValue"))
        XCTAssertTrue(output.contains("let rawValueTotalDigitsCount = rawValueTotalDigitsSource.filter { $0.isNumber }.count"))
        XCTAssertTrue(output.contains(
            "let rawValueFractionDigitsParts = rawValueFractionDigitsSource.split(separator: \".\", maxSplits: 1, omittingEmptySubsequences: false)"
        ))
        XCTAssertTrue(output.contains("[CG_SEMANTIC_008]"))
        XCTAssertTrue(output.contains("[CG_SEMANTIC_009]"))
        XCTAssertTrue(output.contains("[CG_SEMANTIC_014]"))
        XCTAssertTrue(output.contains("[CG_SEMANTIC_015]"))
        XCTAssertTrue(output.contains("[CG_SEMANTIC_010]"))
        XCTAssertTrue(output.contains("[CG_SEMANTIC_011]"))
    }

    func test_buildSource_numericFacetSimpleType_emitsNumericValidation() throws {
        let wsdl = makeWSDL(withTypes: """
        <xsd:simpleType name="Price">
          <xsd:restriction base="xsd:decimal">
            <xsd:minInclusive value="1.25"/>
            <xsd:maxInclusive value="999.99"/>
            <xsd:minExclusive value="1.50"/>
            <xsd:maxExclusive value="999.50"/>
            <xsd:totalDigits value="5"/>
            <xsd:fractionDigits value="2"/>
          </xsd:restriction>
        </xsd:simpleType>
        """)

        let output = try buildSource(from: wsdl)

        XCTAssertTrue(output.contains("public struct Price: Codable, Sendable, Equatable {"))
        XCTAssertTrue(output.contains("public var rawValue: Double"))
        XCTAssertTrue(output.contains("if rawValue < 1.25 {"))
        XCTAssertTrue(output.contains("if rawValue > 999.99 {"))
        XCTAssertTrue(output.contains("if rawValue <= 1.50 {"))
        XCTAssertTrue(output.contains("if rawValue >= 999.50 {"))
        XCTAssertTrue(output.contains("Value must be greater than minExclusive 1.50."))
        XCTAssertTrue(output.contains("Value must be smaller than maxExclusive 999.50."))
        XCTAssertTrue(output.contains("Value exceeds totalDigits 5."))
        XCTAssertTrue(output.contains("Value exceeds fractionDigits 2."))
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

    func test_irBuilder_complexTypeAllGroup_generatesFlatFields() throws {
        let wsdl = makeWSDL(withTypes: """
        <xsd:complexType name="Contact">
          <xsd:all>
            <xsd:element name="name" type="xsd:string"/>
            <xsd:element name="email" type="xsd:string" minOccurs="0"/>
          </xsd:all>
        </xsd:complexType>
        """)

        let ir = try buildIR(from: wsdl)
        let contactType = try XCTUnwrap(ir.generatedTypes.first(where: { $0.swiftTypeName == "Contact" }))

        XCTAssertEqual(contactType.fields.map(\.name), ["name", "email"])
        XCTAssertFalse(contactType.fields[0].isOptional)
        XCTAssertTrue(contactType.fields[1].isOptional)
    }

    func test_irBuilder_inlineAllWrapper_resolvesAnonymousPayloadFields() throws {
        let wsdl = makeDocumentLiteralWSDL(withTypes: """
        <xsd:element name="PerformAction">
          <xsd:complexType>
            <xsd:all>
              <xsd:element name="name" type="xsd:string"/>
              <xsd:element name="email" type="xsd:string" minOccurs="0"/>
            </xsd:all>
          </xsd:complexType>
        </xsd:element>
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

        XCTAssertEqual(payloadType.fields.map(\.name), ["name", "email"])
        XCTAssertFalse(payloadType.fields[0].isOptional)
        XCTAssertTrue(payloadType.fields[1].isOptional)
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

    func test_irBuilder_complexTypeChoiceGroup_preservesChoiceGroupMetadata() throws {
        let wsdl = makeWSDL(withTypes: """
        <xsd:complexType name="Payment">
          <xsd:choice>
            <xsd:element name="cardNumber" type="xsd:string"/>
            <xsd:element name="iban" type="xsd:string"/>
          </xsd:choice>
          <xsd:choice minOccurs="0">
            <xsd:element name="voucherCodes" type="xsd:string" minOccurs="0" maxOccurs="3"/>
            <xsd:element name="couponCode" type="xsd:string" minOccurs="0"/>
          </xsd:choice>
        </xsd:complexType>
        """)

        let ir = try buildIR(from: wsdl)
        let paymentType = try XCTUnwrap(ir.generatedTypes.first(where: { $0.swiftTypeName == "Payment" }))

        XCTAssertEqual(paymentType.fields.map(\.name), ["cardNumber", "iban", "voucherCodes", "couponCode"])
        XCTAssertTrue(paymentType.fields.allSatisfy(\.isOptional))
        XCTAssertEqual(paymentType.choiceGroups.count, 2)
        XCTAssertEqual(
            paymentType.choiceGroups[0],
            GeneratedChoiceGroupIR(fieldNames: ["cardNumber", "iban"], minOccurs: 1, maxOccurs: 1)
        )
        XCTAssertEqual(
            paymentType.choiceGroups[1],
            GeneratedChoiceGroupIR(fieldNames: ["voucherCodes", "couponCode"], minOccurs: 0, maxOccurs: 1)
        )
    }

    func test_irBuilder_complexTypeAttributes_preserveXMLAttributeFieldKind() throws {
        let wsdl = makeWSDL(withTypes: """
        <xsd:complexType name="Order">
          <xsd:sequence>
            <xsd:element name="id" type="xsd:string"/>
          </xsd:sequence>
          <xsd:attribute name="source" type="xsd:string" use="required"/>
          <xsd:attribute name="channel-code" type="xsd:string"/>
        </xsd:complexType>
        """)

        let ir = try buildIR(from: wsdl)
        let orderType = try XCTUnwrap(ir.generatedTypes.first(where: { $0.swiftTypeName == "Order" }))

        let sourceField = try XCTUnwrap(orderType.fields.first(where: { $0.name == "source" }))
        XCTAssertEqual(sourceField.xmlFieldKind, .attribute)
        XCTAssertFalse(sourceField.isOptional)

        let channelCodeField = try XCTUnwrap(orderType.fields.first(where: { $0.name == "channelCode" }))
        XCTAssertEqual(channelCodeField.xmlFieldKind, .attribute)
        XCTAssertTrue(channelCodeField.isOptional)
        XCTAssertEqual(channelCodeField.xmlName, "channel-code")
    }

    func test_irBuilder_attributeGroupReferences_flattenNestedAttributes() throws {
        let wsdl = makeWSDL(withTypes: """
        <xsd:attributeGroup name="BaseMetadata">
          <xsd:attribute name="source" type="xsd:string" use="required"/>
        </xsd:attributeGroup>
        <xsd:attributeGroup name="ExtendedMetadata">
          <xsd:attributeGroup ref="tns:BaseMetadata"/>
          <xsd:attribute name="locale" type="xsd:string"/>
        </xsd:attributeGroup>
        <xsd:complexType name="Order">
          <xsd:sequence>
            <xsd:element name="id" type="xsd:string"/>
          </xsd:sequence>
          <xsd:attributeGroup ref="tns:ExtendedMetadata"/>
        </xsd:complexType>
        """)

        let ir = try buildIR(from: wsdl)
        let orderType = try XCTUnwrap(ir.generatedTypes.first(where: { $0.swiftTypeName == "Order" }))

        XCTAssertEqual(Set(orderType.fields.map(\.name)), Set(["id", "source", "locale"]))
        let sourceField = try XCTUnwrap(orderType.fields.first(where: { $0.name == "source" }))
        let localeField = try XCTUnwrap(orderType.fields.first(where: { $0.name == "locale" }))
        XCTAssertEqual(sourceField.xmlFieldKind, .attribute)
        XCTAssertFalse(sourceField.isOptional)
        XCTAssertEqual(localeField.xmlFieldKind, .attribute)
        XCTAssertTrue(localeField.isOptional)
    }

    func test_irBuilder_simpleContentAttributeGroupReferences_flattenAttributes() throws {
        let wsdl = makeWSDL(withTypes: """
        <xsd:attributeGroup name="BaseMetadata">
          <xsd:attribute name="currency" type="xsd:string" use="required"/>
        </xsd:attributeGroup>
        <xsd:attributeGroup name="ExtendedMetadata">
          <xsd:attributeGroup ref="tns:BaseMetadata"/>
          <xsd:attribute name="locale" type="xsd:string"/>
        </xsd:attributeGroup>
        <xsd:complexType name="Amount">
          <xsd:simpleContent>
            <xsd:extension base="xsd:decimal">
              <xsd:attributeGroup ref="tns:ExtendedMetadata"/>
            </xsd:extension>
          </xsd:simpleContent>
        </xsd:complexType>
        """)

        let ir = try buildIR(from: wsdl)
        let amountType = try XCTUnwrap(ir.generatedTypes.first(where: { $0.swiftTypeName == "Amount" }))

        XCTAssertEqual(Set(amountType.fields.map(\.name)), Set(["value", "currency", "locale"]))
        let valueField = try XCTUnwrap(amountType.fields.first(where: { $0.name == "value" }))
        let currencyField = try XCTUnwrap(amountType.fields.first(where: { $0.name == "currency" }))
        let localeField = try XCTUnwrap(amountType.fields.first(where: { $0.name == "locale" }))
        XCTAssertEqual(valueField.xmlFieldKind, .text)
        XCTAssertEqual(currencyField.xmlFieldKind, .attribute)
        XCTAssertFalse(currencyField.isOptional)
        XCTAssertEqual(localeField.xmlFieldKind, .attribute)
    }

    func test_irBuilder_attributeReferences_resolveTopLevelAttributes() throws {
        let wsdl = makeWSDL(withTypes: """
        <xsd:attribute name="source" type="xsd:string"/>
        <xsd:attribute name="locale" type="xsd:string"/>
        <xsd:attributeGroup name="SharedMetadata">
          <xsd:attribute ref="tns:source" use="required"/>
        </xsd:attributeGroup>
        <xsd:complexType name="Order">
          <xsd:sequence>
            <xsd:element name="id" type="xsd:string"/>
          </xsd:sequence>
          <xsd:attributeGroup ref="tns:SharedMetadata"/>
          <xsd:attribute ref="tns:locale"/>
        </xsd:complexType>
        """)

        let ir = try buildIR(from: wsdl)
        let orderType = try XCTUnwrap(ir.generatedTypes.first(where: { $0.swiftTypeName == "Order" }))
        let sourceField = try XCTUnwrap(orderType.fields.first(where: { $0.name == "source" }))
        let localeField = try XCTUnwrap(orderType.fields.first(where: { $0.name == "locale" }))

        XCTAssertEqual(Set(orderType.fields.map(\.name)), Set(["id", "source", "locale"]))
        XCTAssertEqual(sourceField.xmlFieldKind, .attribute)
        XCTAssertFalse(sourceField.isOptional)
        XCTAssertEqual(localeField.xmlFieldKind, .attribute)
        XCTAssertTrue(localeField.isOptional)
    }

    func test_irBuilder_simpleContentAttributeReferences_resolveTopLevelAttributes() throws {
        let wsdl = makeWSDL(withTypes: """
        <xsd:attribute name="currency" type="xsd:string"/>
        <xsd:attribute name="locale" type="xsd:string"/>
        <xsd:attributeGroup name="SharedMetadata">
          <xsd:attribute ref="tns:currency" use="required"/>
        </xsd:attributeGroup>
        <xsd:complexType name="Amount">
          <xsd:simpleContent>
            <xsd:extension base="xsd:decimal">
              <xsd:attributeGroup ref="tns:SharedMetadata"/>
              <xsd:attribute ref="tns:locale"/>
            </xsd:extension>
          </xsd:simpleContent>
        </xsd:complexType>
        """)

        let ir = try buildIR(from: wsdl)
        let amountType = try XCTUnwrap(ir.generatedTypes.first(where: { $0.swiftTypeName == "Amount" }))
        let currencyField = try XCTUnwrap(amountType.fields.first(where: { $0.name == "currency" }))
        let localeField = try XCTUnwrap(amountType.fields.first(where: { $0.name == "locale" }))

        XCTAssertEqual(Set(amountType.fields.map(\.name)), Set(["value", "currency", "locale"]))
        XCTAssertEqual(currencyField.xmlFieldKind, .attribute)
        XCTAssertFalse(currencyField.isOptional)
        XCTAssertEqual(localeField.xmlFieldKind, .attribute)
        XCTAssertTrue(localeField.isOptional)
    }

    func test_irBuilder_simpleContent_generatesTextAndFlattenedAttributeFields() throws {
        let wsdl = makeWSDL(withTypes: """
        <xsd:complexType name="Amount">
          <xsd:simpleContent>
            <xsd:extension base="xsd:decimal">
              <xsd:attribute name="currency" type="xsd:string" use="required"/>
            </xsd:extension>
          </xsd:simpleContent>
        </xsd:complexType>
        <xsd:complexType name="LabeledAmount">
          <xsd:simpleContent>
            <xsd:extension base="tns:Amount">
              <xsd:attribute name="label" type="xsd:string"/>
            </xsd:extension>
          </xsd:simpleContent>
        </xsd:complexType>
        """)

        let ir = try buildIR(from: wsdl)
        let amountType = try XCTUnwrap(ir.generatedTypes.first(where: { $0.swiftTypeName == "Amount" }))
        let labeledAmountType = try XCTUnwrap(ir.generatedTypes.first(where: { $0.swiftTypeName == "LabeledAmount" }))

        XCTAssertEqual(amountType.fields.map(\.name), ["value", "currency"])
        XCTAssertEqual(amountType.fields.first?.xmlFieldKind, .text)
        XCTAssertEqual(amountType.fields.first?.swiftTypeName, "Double")
        XCTAssertEqual(amountType.fields.last?.xmlFieldKind, .attribute)

        XCTAssertEqual(labeledAmountType.fields.map(\.name), ["value", "currency", "label"])
        XCTAssertEqual(labeledAmountType.fields.first?.xmlFieldKind, .text)
        XCTAssertEqual(labeledAmountType.fields[1].xmlFieldKind, .attribute)
        XCTAssertEqual(labeledAmountType.fields[2].xmlFieldKind, .attribute)
    }

    func test_irBuilder_simpleContentExtension_generatesProtocolHierarchy() throws {
        let wsdl = makeWSDL(withTypes: """
        <xsd:complexType name="Amount">
          <xsd:simpleContent>
            <xsd:extension base="xsd:decimal">
              <xsd:attribute name="currency" type="xsd:string" use="required"/>
            </xsd:extension>
          </xsd:simpleContent>
        </xsd:complexType>
        <xsd:complexType name="LabeledAmount">
          <xsd:simpleContent>
            <xsd:extension base="tns:Amount">
              <xsd:attribute name="label" type="xsd:string"/>
            </xsd:extension>
          </xsd:simpleContent>
        </xsd:complexType>
        """)

        let ir = try buildIR(from: wsdl)

        let amountProtocol = try XCTUnwrap(
            ir.generatedProtocols.first(where: { $0.swiftTypeName == "AmountProtocol" })
        )
        XCTAssertEqual(amountProtocol.inheritedProtocolNames, [])
        XCTAssertEqual(amountProtocol.fields.map(\.name), ["value", "currency"])

        let labeledAmountProtocol = try XCTUnwrap(
            ir.generatedProtocols.first(where: { $0.swiftTypeName == "LabeledAmountProtocol" })
        )
        XCTAssertEqual(labeledAmountProtocol.inheritedProtocolNames, ["AmountProtocol"])
        XCTAssertEqual(labeledAmountProtocol.fields.map(\.name), ["label"])
    }

    func test_irBuilder_simpleTypeRestriction_emitsTextBackedRawValueField() throws {
        let wsdl = makeWSDL(withTypes: """
        <xsd:simpleType name="Price">
          <xsd:restriction base="xsd:decimal">
            <xsd:minInclusive value="1.25"/>
            <xsd:maxInclusive value="999.99"/>
          </xsd:restriction>
        </xsd:simpleType>
        """)

        let ir = try buildIR(from: wsdl)
        let priceType = try XCTUnwrap(ir.generatedTypes.first(where: { $0.swiftTypeName == "Price" }))
        let rawValueField = try XCTUnwrap(priceType.fields.first(where: { $0.name == "rawValue" }))

        XCTAssertEqual(rawValueField.xmlFieldKind, .text)
        XCTAssertEqual(rawValueField.swiftTypeName, "Double")
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

    func test_buildSource_choiceGroup_emitsRequiredAndOptionalChoiceValidation() throws {
        let wsdl = makeWSDL(withTypes: """
        <xsd:complexType name="Payment">
          <xsd:choice>
            <xsd:element name="cardNumber" type="xsd:string"/>
            <xsd:element name="iban" type="xsd:string"/>
          </xsd:choice>
          <xsd:choice minOccurs="0">
            <xsd:element name="voucherCodes" type="xsd:string" minOccurs="0" maxOccurs="3"/>
            <xsd:element name="couponCode" type="xsd:string" minOccurs="0"/>
          </xsd:choice>
        </xsd:complexType>
        """)

        let output = try buildSource(from: wsdl)

        XCTAssertTrue(output.contains("public struct Payment: Codable, Sendable, Equatable {"))
        XCTAssertTrue(output.contains("public var cardNumber: String?"))
        XCTAssertTrue(output.contains("public var voucherCodes: [String]?"))
        XCTAssertTrue(output.contains("if choiceGroup0SelectionCount == 0 {"))
        XCTAssertTrue(output.contains("if choiceGroup0SelectionCount > 1 {"))
        XCTAssertFalse(output.contains("if choiceGroup1SelectionCount == 0 {"))
        XCTAssertTrue(output.contains("if choiceGroup1SelectionCount > 1 {"))
    }

    func test_buildSource_attributeFields_emitMacroAnnotationsOnSwift59() throws {
        let wsdl = makeWSDL(withTypes: """
        <xsd:complexType name="Order">
          <xsd:sequence>
            <xsd:element name="id" type="xsd:string"/>
          </xsd:sequence>
          <xsd:attribute name="source" type="xsd:string" use="required"/>
          <xsd:attribute name="channel-code" type="xsd:string"/>
        </xsd:complexType>
        """)

        let output = try buildSource(from: wsdl)

        XCTAssertTrue(output.contains("import SwiftSOAPXML"))
        XCTAssertTrue(output.contains("import SwiftSOAPXMLMacros"))
        XCTAssertTrue(output.contains("@XMLCodable"))
        XCTAssertTrue(output.contains("public struct Order: Codable, Sendable, Equatable {"))
        XCTAssertTrue(output.contains("@XMLAttribute"))
        XCTAssertTrue(output.contains("public var source: String"))
        XCTAssertTrue(output.contains("public var channelCode: String?"))
        XCTAssertTrue(output.contains("case channelCode = \"channel-code\""))
        XCTAssertFalse(output.contains("XMLFieldCodingOverrideProvider"))
        XCTAssertFalse(output.contains("xmlFieldNodeKinds"))
    }

    func test_buildSource_attributeFields_emitPropertyWrappersBeforeSwift59() throws {
        let wsdl = makeWSDL(withTypes: """
        <xsd:complexType name="Order">
          <xsd:sequence>
            <xsd:element name="id" type="xsd:string"/>
          </xsd:sequence>
          <xsd:attribute name="source" type="xsd:string" use="required"/>
        </xsd:complexType>
        """)

        let output = try buildSource(
            from: wsdl,
            targetSwiftVersion: SwiftLanguageVersion(major: 5, minor: 8)
        )

        XCTAssertTrue(output.contains("import SwiftSOAPXML"))
        XCTAssertFalse(output.contains("import SwiftSOAPXMLMacros"))
        XCTAssertFalse(output.contains("@XMLCodable"))
        XCTAssertTrue(output.contains("@SwiftSOAPXML.XMLAttribute"))
        XCTAssertTrue(output.contains("public struct Order: Codable, Sendable, Equatable {"))
        XCTAssertFalse(output.contains("XMLFieldCodingOverrideProvider"))
        XCTAssertFalse(output.contains("xmlFieldNodeKinds"))
    }

    func test_buildSource_simpleContent_emitsManualTextAndAttributeCodable() throws {
        let wsdl = makeWSDL(withTypes: """
        <xsd:complexType name="Amount">
          <xsd:simpleContent>
            <xsd:extension base="xsd:decimal">
              <xsd:attribute name="currency" type="xsd:string" use="required"/>
            </xsd:extension>
          </xsd:simpleContent>
        </xsd:complexType>
        """)

        let output = try buildSource(from: wsdl)

        XCTAssertTrue(output.contains("import SwiftSOAPXMLMacros"))
        XCTAssertTrue(output.contains("@XMLCodable"))
        XCTAssertTrue(output.contains("public struct Amount: Codable, Sendable, Equatable {"))
        XCTAssertTrue(output.contains("public var value: Double"))
        XCTAssertTrue(output.contains("@XMLAttribute"))
        XCTAssertTrue(output.contains("public var currency: String"))
        XCTAssertTrue(output.contains("let container = try decoder.container(keyedBy: CodingKeys.self)"))
        XCTAssertTrue(output.contains("let valueContainer = try decoder.singleValueContainer()"))
        XCTAssertTrue(output.contains("var valueContainer = encoder.singleValueContainer()"))
        XCTAssertTrue(output.contains("try valueContainer.encode(value)"))
        XCTAssertFalse(output.contains("XMLFieldCodingOverrideProvider"))
    }

    func test_buildSource_simpleTypeRestriction_emitsSingleValueCodableAndValidation() throws {
        let wsdl = makeWSDL(withTypes: """
        <xsd:simpleType name="Price">
          <xsd:restriction base="xsd:decimal">
            <xsd:minInclusive value="1.25"/>
            <xsd:maxInclusive value="999.99"/>
          </xsd:restriction>
        </xsd:simpleType>
        """)

        let output = try buildSource(from: wsdl)

        XCTAssertTrue(output.contains("public struct Price: Codable, Sendable, Equatable {"))
        XCTAssertTrue(output.contains("public var rawValue: Double"))
        XCTAssertTrue(output.contains("self.rawValue = try valueContainer.decode(Double.self)"))
        XCTAssertTrue(output.contains("try valueContainer.encode(rawValue)"))
        XCTAssertTrue(output.contains("if rawValue < 1.25 {"))
        XCTAssertTrue(output.contains("if rawValue > 999.99 {"))
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

private func buildSource(
    from wsdl: String,
    targetSwiftVersion: SwiftLanguageVersion = SwiftLanguageVersion(major: 5, minor: 9)
) throws -> String {
    let ir = try buildIR(from: wsdl)
    let emitter = SwiftCodeEmitter()
    let profile = CodeGenerationSyntaxProfile(
        targetSwiftVersion: targetSwiftVersion,
        useExistentialAny: false,
        useTypedThrowsAnyError: false
    )
    return emitter.emit(ir: ir, syntaxProfile: profile).map(\.contents).joined(separator: "\n")
}
