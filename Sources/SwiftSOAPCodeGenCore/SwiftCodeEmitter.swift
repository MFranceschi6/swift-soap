import Foundation
// swiftlint:disable:next blanket_disable_command
// swiftlint:disable file_length line_length

public struct SwiftCodeEmitter: SwiftSourceEmitter {
    public init() {}

    // MARK: - Protocol conformance

    public func emit(ir: SOAPCodeGenerationIR, syntaxProfile: CodeGenerationSyntaxProfile) -> [GeneratedSourceArtifact] {
        let fileHeader = makeFileHeader(syntaxProfile: syntaxProfile)
        var artifacts: [GeneratedSourceArtifact] = []

        // Marker file – declared by the build-tool plugin as output stamp for incremental builds.
        // SPM compiles all .swift files found in the plugin work directory automatically.
        artifacts.append(GeneratedSourceArtifact(
            fileName: "\(ir.moduleName)+GeneratedSOAP.swift",
            contents: fileHeader + "\n// Module: \(ir.moduleName)\n"
        ))

        artifacts.append(contentsOf: emitProtocolArtifacts(ir: ir, fileHeader: fileHeader))
        artifacts.append(contentsOf: emitTypeArtifacts(
            ir: ir,
            fileHeader: fileHeader,
            syntaxProfile: syntaxProfile
        ))
        artifacts.append(contentsOf: emitOperationsArtifacts(ir: ir, fileHeader: fileHeader))
        artifacts.append(contentsOf: emitClientArtifacts(ir: ir, fileHeader: fileHeader, syntaxProfile: syntaxProfile))
        artifacts.append(contentsOf: emitServerArtifacts(ir: ir, fileHeader: fileHeader, syntaxProfile: syntaxProfile))

        return artifacts
    }
}

// MARK: - Artifact builders

private extension SwiftCodeEmitter {
    func emitProtocolArtifacts(ir: SOAPCodeGenerationIR, fileHeader: String) -> [GeneratedSourceArtifact] {
        ir.generatedProtocols.map { generatedProtocol in
            var lines: [String] = []
            lines.append(contentsOf: baseImports(forProtocol: generatedProtocol))
            lines.append("")
            lines.append(fileHeader)
            lines.append("")
            lines.append(contentsOf: emitProtocol(generatedProtocol))
            lines.append("")
            return GeneratedSourceArtifact(
                fileName: "\(generatedProtocol.swiftTypeName).swift",
                contents: lines.joined(separator: "\n")
            )
        }
    }

    func emitTypeArtifacts(
        ir: SOAPCodeGenerationIR,
        fileHeader: String,
        syntaxProfile: CodeGenerationSyntaxProfile
    ) -> [GeneratedSourceArtifact] {
        ir.generatedTypes.map { generatedType in
            var lines: [String] = []
            lines.append(contentsOf: baseImports(forType: generatedType, syntaxProfile: syntaxProfile))
            lines.append("")
            lines.append(fileHeader)
            lines.append("")
            lines.append(contentsOf: emitType(
                generatedType,
                validationProfile: ir.validationProfile,
                syntaxProfile: syntaxProfile
            ))
            lines.append("")
            return GeneratedSourceArtifact(
                fileName: "\(generatedType.swiftTypeName).swift",
                contents: lines.joined(separator: "\n")
            )
        }
    }

    func emitOperationsArtifacts(ir: SOAPCodeGenerationIR, fileHeader: String) -> [GeneratedSourceArtifact] {
        ir.services.flatMap { service in
            service.ports.map { port in
                let identifierEnumName = "\(service.swiftTypeName)\(port.swiftTypeName)OperationIdentifier"
                let hasActions = port.operations.contains { $0.soapAction != nil }
                let actionEnumName: String? = hasActions
                    ? "\(service.swiftTypeName)\(port.swiftTypeName)OperationAction"
                    : nil
                var lines: [String] = []
                lines.append("import Foundation")
                lines.append("import SwiftSOAPCore")
                lines.append("")
                lines.append(fileHeader)
                lines.append("")
                lines.append(contentsOf: emitOperationEnums(service, port: port))
                lines.append("")
                for operation in port.operations {
                    lines.append(contentsOf: emitOperationContract(
                        operation,
                        identifierEnumName: identifierEnumName,
                        actionEnumName: actionEnumName
                    ))
                    lines.append("")
                }
                return GeneratedSourceArtifact(
                    fileName: "\(service.swiftTypeName)\(port.swiftTypeName)Operations.swift",
                    contents: lines.joined(separator: "\n")
                )
            }
        }
    }

    func emitClientArtifacts(
        ir: SOAPCodeGenerationIR,
        fileHeader: String,
        syntaxProfile: CodeGenerationSyntaxProfile
    ) -> [GeneratedSourceArtifact] {
        var artifacts: [GeneratedSourceArtifact] = []
        guard ir.generationScope.contains(.client) else { return artifacts }

        if ir.runtimeTargets.contains(.async) {
            for service in ir.services {
                for port in service.ports {
                    var lines: [String] = []
                    lines.append("import Foundation")
                    lines.append("import SwiftSOAPCore")
                    lines.append("import SwiftSOAPClientAsync")
                    lines.append("")
                    lines.append(fileHeader)
                    lines.append("")
                    lines.append(contentsOf: emitAsyncClientLines(service: service, port: port, syntaxProfile: syntaxProfile))
                    lines.append("")
                    artifacts.append(GeneratedSourceArtifact(
                        fileName: "\(service.swiftTypeName)\(port.swiftTypeName)AsyncClient.swift",
                        contents: lines.joined(separator: "\n")
                    ))
                }
            }
        }

        if ir.runtimeTargets.contains(.nio) {
            for service in ir.services {
                for port in service.ports {
                    var lines: [String] = []
                    lines.append("import Foundation")
                    lines.append("import NIOCore")
                    lines.append("import SwiftSOAPCore")
                    lines.append("import SwiftSOAPClientNIO")
                    lines.append("")
                    lines.append(fileHeader)
                    lines.append("")
                    lines.append(contentsOf: emitNIOClientLines(service: service, port: port, syntaxProfile: syntaxProfile))
                    lines.append("")
                    artifacts.append(GeneratedSourceArtifact(
                        fileName: "\(service.swiftTypeName)\(port.swiftTypeName)NIOClient.swift",
                        contents: lines.joined(separator: "\n")
                    ))
                }
            }
        }

        return artifacts
    }

    func emitServerArtifacts(
        ir: SOAPCodeGenerationIR,
        fileHeader: String,
        syntaxProfile: CodeGenerationSyntaxProfile
    ) -> [GeneratedSourceArtifact] {
        var artifacts: [GeneratedSourceArtifact] = []
        guard ir.generationScope.contains(.server) else { return artifacts }

        if ir.runtimeTargets.contains(.async) {
            for service in ir.services {
                for port in service.ports {
                    var lines: [String] = []
                    lines.append("import Foundation")
                    lines.append("import SwiftSOAPCore")
                    lines.append("import SwiftSOAPServerAsync")
                    lines.append("")
                    lines.append(fileHeader)
                    lines.append("")
                    lines.append(contentsOf: emitAsyncServerLines(service: service, port: port, syntaxProfile: syntaxProfile))
                    lines.append("")
                    artifacts.append(GeneratedSourceArtifact(
                        fileName: "\(service.swiftTypeName)\(port.swiftTypeName)AsyncServer.swift",
                        contents: lines.joined(separator: "\n")
                    ))
                }
            }
        }

        if ir.runtimeTargets.contains(.nio) {
            for service in ir.services {
                for port in service.ports {
                    var lines: [String] = []
                    lines.append("import Foundation")
                    lines.append("import NIOCore")
                    lines.append("import SwiftSOAPCore")
                    lines.append("import SwiftSOAPServerNIO")
                    lines.append("")
                    lines.append(fileHeader)
                    lines.append("")
                    lines.append(contentsOf: emitNIOServerLines(service: service, port: port, syntaxProfile: syntaxProfile))
                    lines.append("")
                    artifacts.append(GeneratedSourceArtifact(
                        fileName: "\(service.swiftTypeName)\(port.swiftTypeName)NIOServer.swift",
                        contents: lines.joined(separator: "\n")
                    ))
                }
            }
        }

        return artifacts
    }
}

// MARK: - Imports

private extension SwiftCodeEmitter {
    func makeFileHeader(syntaxProfile: CodeGenerationSyntaxProfile) -> String {
        "// Generated by SwiftSOAPCodeGen. Do not edit manually.\n// Target Swift version: \(syntaxProfile.targetSwiftVersion.description)"
    }

    func baseImports(forProtocol _: GeneratedProtocolIR) -> [String] {
        ["import Foundation"]
    }

    func baseImports(
        forType generatedType: GeneratedTypeIR,
        syntaxProfile: CodeGenerationSyntaxProfile
    ) -> [String] {
        var imports = ["import Foundation", "import SwiftSOAPCore"]
        if generatedType.xmlRootElementName != nil || generatedType.fields.contains(where: { $0.xmlFieldKind == .attribute }) {
            imports.append("import SwiftSOAPXML")
        }
        if shouldUseXMLFieldCodingMacros(
            for: generatedType.fields,
            syntaxProfile: syntaxProfile
        ) {
            imports.append("import SwiftSOAPXMLMacros")
        }
        return imports
    }
}

// MARK: - Type emission

private extension SwiftCodeEmitter {
    func emitProtocol(_ generatedProtocol: GeneratedProtocolIR) -> [String] {
        var lines: [String] = []
        let inheritedProtocols = generatedProtocol.inheritedProtocolNames.isEmpty
            ? ["Sendable"]
            : generatedProtocol.inheritedProtocolNames
        let orderedFields = orderedFields(from: generatedProtocol.fields)

        lines.append("public protocol \(generatedProtocol.swiftTypeName): \(inheritedProtocols.joined(separator: ", ")) {")
        for field in orderedFields {
            let optionalSuffix = field.isOptional ? "?" : ""
            lines.append("    var \(field.name): \(field.swiftTypeName)\(optionalSuffix) { get set }")
        }
        lines.append("}")
        return lines
    }

    func emitType(
        _ generatedType: GeneratedTypeIR,
        validationProfile: ValidationProfile,
        syntaxProfile: CodeGenerationSyntaxProfile
    ) -> [String] {
        switch generatedType.kind {
        case .bodyPayload:
            return emitStruct(
                name: generatedType.swiftTypeName,
                protocols: ["SOAPBodyPayload", "Equatable"] + generatedType.protocolConformances,
                fields: generatedType.fields,
                choiceGroups: generatedType.choiceGroups,
                xmlRootElementName: generatedType.xmlRootElementName,
                xmlRootElementNamespaceURI: generatedType.xmlRootElementNamespaceURI,
                validationProfile: validationProfile,
                syntaxProfile: syntaxProfile
            )
        case .faultDetailPayload:
            return emitStruct(
                name: generatedType.swiftTypeName,
                protocols: ["SOAPFaultDetailPayload", "Equatable"] + generatedType.protocolConformances,
                fields: generatedType.fields,
                choiceGroups: generatedType.choiceGroups,
                xmlRootElementName: nil,
                xmlRootElementNamespaceURI: nil,
                validationProfile: validationProfile,
                syntaxProfile: syntaxProfile
            )
        case .schemaModel:
            return emitStruct(
                name: generatedType.swiftTypeName,
                protocols: ["Codable", "Sendable", "Equatable"] + generatedType.protocolConformances,
                fields: generatedType.fields,
                choiceGroups: generatedType.choiceGroups,
                xmlRootElementName: nil,
                xmlRootElementNamespaceURI: nil,
                validationProfile: validationProfile,
                syntaxProfile: syntaxProfile
            )
        case .enumeration:
            return emitEnumType(generatedType)
        }
    }

    func emitEnumType(_ generatedType: GeneratedTypeIR) -> [String] {
        var lines: [String] = []
        lines.append("public enum \(generatedType.swiftTypeName): String, Codable, Sendable, Equatable {")
        for rawValue in generatedType.enumerationCases {
            let caseName = sanitizeEnumCaseName(rawValue)
            if caseName == rawValue {
                lines.append("    case \(caseName)")
            } else {
                lines.append("    case \(caseName) = \"\(rawValue)\"")
            }
        }
        lines.append("}")
        return lines
    }

    // swiftlint:disable:next function_body_length
    func emitStruct(
        name: String,
        protocols: [String],
        fields: [GeneratedTypeFieldIR],
        choiceGroups: [GeneratedChoiceGroupIR],
        xmlRootElementName: String?,
        xmlRootElementNamespaceURI: String?,
        validationProfile: ValidationProfile,
        syntaxProfile: CodeGenerationSyntaxProfile
    ) -> [String] {
        var lines: [String] = []
        var conformances = protocols
        let useXMLFieldCodingMacros = shouldUseXMLFieldCodingMacros(
            for: fields,
            syntaxProfile: syntaxProfile
        )
        if xmlRootElementName != nil {
            conformances.append("XMLRootNode")
        }

        let orderedFields = orderedFields(from: fields)
        let textField = orderedFields.first(where: { $0.xmlFieldKind == .text })
        let keyedFields = orderedFields.filter { $0.xmlFieldKind != .text }

        let needsCodingKeys = keyedFields.contains { field in
            guard let xmlName = field.xmlName else { return false }
            return xmlName != field.name
        }
        let shouldEmitCodingKeys = !keyedFields.isEmpty && (textField != nil || needsCodingKeys)

        if useXMLFieldCodingMacros {
            lines.append("@XMLCodable")
        }
        lines.append("public struct \(name): \(conformances.joined(separator: ", ")) {")

        if let rootName = xmlRootElementName {
            lines.append("    public static var xmlRootElementName: String { \"\(rootName)\" }")
            if let namespaceURI = xmlRootElementNamespaceURI {
                lines.append("    public static var xmlRootElementNamespaceURI: String? { \"\(namespaceURI)\" }")
            }
            lines.append("")
        }

        if orderedFields.isEmpty {
            lines.append("    public init() {}")
            lines.append("}")
            return lines
        }

        for field in orderedFields {
            let optionalSuffix = field.isOptional ? "?" : ""
            if field.xmlFieldKind == .attribute {
                lines.append("    \(xmlAttributeAnnotation(useMacros: useXMLFieldCodingMacros))")
            }
            lines.append("    public var \(field.name): \(field.swiftTypeName)\(optionalSuffix)")
        }

        if shouldEmitCodingKeys {
            lines.append("")
            lines.append("    public enum CodingKeys: String, CodingKey {")
            for field in keyedFields {
                let xmlName = field.xmlName ?? field.name
                if xmlName != field.name {
                    lines.append("        case \(field.name) = \"\(xmlName)\"")
                } else {
                    lines.append("        case \(field.name)")
                }
            }
            lines.append("    }")
        }

        let initializerSignature = orderedFields
            .map { field -> String in
                let optionalSuffix = field.isOptional ? "?" : ""
                return "\(field.name): \(field.swiftTypeName)\(optionalSuffix)"
            }
            .joined(separator: ", ")
        lines.append("")
        lines.append("    public init(\(initializerSignature)) {")
        for field in orderedFields {
            lines.append("        self.\(field.name) = \(field.name)")
        }
        lines.append("    }")

        if let textField = textField {
            lines.append(contentsOf: emitTextBackedCodable(
                textField: textField,
                keyedFields: keyedFields
            ))
        }

        if validationProfile == .strict {
            let constrainedFields = orderedFields.filter { hasValidationRules(field: $0) }
            let fieldsByName = Dictionary(uniqueKeysWithValues: orderedFields.map { ($0.name, $0) })
            let validatableChoiceGroups = choiceGroups.filter { choiceGroup in
                choiceGroup.fieldNames.allSatisfy { fieldsByName[$0] != nil }
            }
            if !constrainedFields.isEmpty || !validatableChoiceGroups.isEmpty {
                lines.append("")
                lines.append("    /// Validates field constraints derived from XSD facets and occurrence bounds.")
                lines.append("    /// - Throws: `SOAPSemanticValidationError` on constraint violation.")
                lines.append("    public func validate() throws {")
                for field in constrainedFields {
                    lines.append(contentsOf: emitFieldValidation(field: field))
                }
                for (index, choiceGroup) in validatableChoiceGroups.enumerated() {
                    lines.append(contentsOf: emitChoiceGroupValidation(
                        choiceGroup: choiceGroup,
                        groupIndex: index,
                        fieldsByName: fieldsByName
                    ))
                }
                lines.append("    }")
            }
        }

        lines.append("}")
        return lines
    }

    func shouldUseXMLFieldCodingMacros(
        for fields: [GeneratedTypeFieldIR],
        syntaxProfile: CodeGenerationSyntaxProfile
    ) -> Bool {
        fields.contains(where: { $0.xmlFieldKind == .attribute }) &&
            syntaxProfile.targetSwiftVersion >= SwiftLanguageVersion(major: 5, minor: 9)
    }

    func xmlAttributeAnnotation(useMacros: Bool) -> String {
        useMacros ? "@XMLAttribute" : "@SwiftSOAPXML.XMLAttribute"
    }

    func emitTextBackedCodable(
        textField: GeneratedTypeFieldIR,
        keyedFields: [GeneratedTypeFieldIR]
    ) -> [String] {
        var lines: [String] = []

        lines.append("")
        lines.append("    public init(from decoder: Decoder) throws {")
        if !keyedFields.isEmpty {
            lines.append("        let container = try decoder.container(keyedBy: CodingKeys.self)")
            for field in keyedFields {
                if field.isOptional {
                    lines.append("        self.\(field.name) = try container.decodeIfPresent(\(field.swiftTypeName).self, forKey: .\(field.name))")
                } else {
                    lines.append("        self.\(field.name) = try container.decode(\(field.swiftTypeName).self, forKey: .\(field.name))")
                }
            }
        }
        lines.append("        let valueContainer = try decoder.singleValueContainer()")
        if textField.isOptional {
            lines.append("        if valueContainer.decodeNil() {")
            lines.append("            self.\(textField.name) = nil")
            lines.append("        } else {")
            lines.append("            self.\(textField.name) = try valueContainer.decode(\(textField.swiftTypeName).self)")
            lines.append("        }")
        } else {
            lines.append("        self.\(textField.name) = try valueContainer.decode(\(textField.swiftTypeName).self)")
        }
        lines.append("    }")
        lines.append("")
        lines.append("    public func encode(to encoder: Encoder) throws {")
        if !keyedFields.isEmpty {
            lines.append("        var container = encoder.container(keyedBy: CodingKeys.self)")
            for field in keyedFields {
                if field.isOptional {
                    lines.append("        try container.encodeIfPresent(\(field.name), forKey: .\(field.name))")
                } else {
                    lines.append("        try container.encode(\(field.name), forKey: .\(field.name))")
                }
            }
        }
        lines.append("        var valueContainer = encoder.singleValueContainer()")
        if textField.isOptional {
            lines.append("        if let value = \(textField.name) {")
            lines.append("            try valueContainer.encode(value)")
            lines.append("        } else {")
            lines.append("            try valueContainer.encodeNil()")
            lines.append("        }")
        } else {
            lines.append("        try valueContainer.encode(\(textField.name))")
        }
        lines.append("    }")

        return lines
    }

    func orderedFields(from fields: [GeneratedTypeFieldIR]) -> [GeneratedTypeFieldIR] {
        fields.enumerated().sorted { lhs, rhs in
            switch (lhs.element.xmlOrder, rhs.element.xmlOrder) {
            case let (lhsOrder?, rhsOrder?):
                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                break
            }

            return lhs.offset < rhs.offset
        }
        .map(\.element)
    }

    func emitFieldValidation(field: GeneratedTypeFieldIR) -> [String] {
        var lines: [String] = []
        lines.append(contentsOf: emitOccurrenceValidation(field: field))
        for constraint in field.constraints {
            switch constraint.kind {
            case .minLength:
                let check = field.isOptional
                    ? "if let v = \(field.name), v.count < \(constraint.value)"
                    : "if \(field.name).count < \(constraint.value)"
                lines.append("        \(check) {")
                lines.append("            throw SOAPSemanticValidationError(field: \"\(field.name)\", code: \"[CG_SEMANTIC_001]\", message: \"Value is shorter than minLength \(constraint.value).\")")
                lines.append("        }")
            case .maxLength:
                let check = field.isOptional
                    ? "if let v = \(field.name), v.count > \(constraint.value)"
                    : "if \(field.name).count > \(constraint.value)"
                lines.append("        \(check) {")
                lines.append("            throw SOAPSemanticValidationError(field: \"\(field.name)\", code: \"[CG_SEMANTIC_002]\", message: \"Value exceeds maxLength \(constraint.value).\")")
                lines.append("        }")
            case .length:
                let check = field.isOptional
                    ? "if let v = \(field.name), v.count != \(constraint.value)"
                    : "if \(field.name).count != \(constraint.value)"
                lines.append("        \(check) {")
                lines.append("            throw SOAPSemanticValidationError(field: \"\(field.name)\", code: \"[CG_SEMANTIC_003]\", message: \"Value length must be exactly \(constraint.value).\")")
                lines.append("        }")
            case .pattern:
                let src = field.isOptional ? "\(field.name) ?? \"\"" : "\(field.name)"
                lines.append("        if (try? NSRegularExpression(pattern: \"\(constraint.value)\"))?.firstMatch(in: \(src), range: NSRange(\(src).startIndex..., in: \(src))) == nil {")
                lines.append("            throw SOAPSemanticValidationError(field: \"\(field.name)\", code: \"[CG_SEMANTIC_004]\", message: \"Value does not match pattern \\\"\(constraint.value)\\\".\")")
                lines.append("        }")
            case .minInclusive:
                lines.append(contentsOf: emitNumericRangeValidation(
                    field: field,
                    invalidIf: "<",
                    threshold: constraint.value,
                    diagnosticCode: "[CG_SEMANTIC_008]",
                    message: "Value is smaller than minInclusive \(constraint.value)."
                ))
            case .maxInclusive:
                lines.append(contentsOf: emitNumericRangeValidation(
                    field: field,
                    invalidIf: ">",
                    threshold: constraint.value,
                    diagnosticCode: "[CG_SEMANTIC_009]",
                    message: "Value exceeds maxInclusive \(constraint.value)."
                ))
            case .minExclusive:
                lines.append(contentsOf: emitNumericRangeValidation(
                    field: field,
                    invalidIf: "<=",
                    threshold: constraint.value,
                    diagnosticCode: "[CG_SEMANTIC_014]",
                    message: "Value must be greater than minExclusive \(constraint.value)."
                ))
            case .maxExclusive:
                lines.append(contentsOf: emitNumericRangeValidation(
                    field: field,
                    invalidIf: ">=",
                    threshold: constraint.value,
                    diagnosticCode: "[CG_SEMANTIC_015]",
                    message: "Value must be smaller than maxExclusive \(constraint.value)."
                ))
            case .totalDigits:
                lines.append(contentsOf: emitTotalDigitsValidation(field: field, constraintValue: constraint.value))
            case .fractionDigits:
                lines.append(contentsOf: emitFractionDigitsValidation(field: field, constraintValue: constraint.value))
            }
        }
        return lines
    }

    func hasValidationRules(field: GeneratedTypeFieldIR) -> Bool {
        !field.constraints.isEmpty || field.minOccurs != nil || field.maxOccurs != nil
    }

    func emitChoiceGroupValidation(
        choiceGroup: GeneratedChoiceGroupIR,
        groupIndex: Int,
        fieldsByName: [String: GeneratedTypeFieldIR]
    ) -> [String] {
        guard choiceGroup.maxOccurs == 1 else {
            return []
        }

        let selectionTerms = choiceGroup.fieldNames.compactMap { fieldName -> String? in
            guard let field = fieldsByName[fieldName] else {
                return nil
            }
            return choiceSelectionCountExpression(for: field)
        }
        guard !selectionTerms.isEmpty else {
            return []
        }

        let selectionCountName = "choiceGroup\(groupIndex)SelectionCount"
        let fieldLabel = choiceGroup.fieldNames.joined(separator: ", ")
        var lines = [
            "        let \(selectionCountName) = \(selectionTerms.joined(separator: " + "))"
        ]

        if choiceGroup.minOccurs > 0 {
            lines.append("        if \(selectionCountName) == 0 {")
            lines.append("            throw SOAPSemanticValidationError(field: \"\(fieldLabel)\", code: \"[CG_SEMANTIC_012]\", message: \"Choice group requires at least one value.\")")
            lines.append("        }")
        }

        lines.append("        if \(selectionCountName) > 1 {")
        lines.append("            throw SOAPSemanticValidationError(field: \"\(fieldLabel)\", code: \"[CG_SEMANTIC_013]\", message: \"Choice group allows at most one value.\")")
        lines.append("        }")
        return lines
    }

    func emitOccurrenceValidation(field: GeneratedTypeFieldIR) -> [String] {
        guard field.minOccurs != nil || field.maxOccurs != nil else {
            return []
        }

        var lines: [String] = []
        let minOccurs = field.minOccurs ?? 0

        if field.isOptional {
            lines.append("        if let value = \(field.name) {")
            lines.append(contentsOf: emitOccurrenceChecks(field: field, valueName: "value", minOccurs: minOccurs, indent: "            "))
            lines.append("        }")
            return lines
        }

        lines.append(contentsOf: emitOccurrenceChecks(field: field, valueName: field.name, minOccurs: minOccurs, indent: "        "))
        return lines
    }

    func emitOccurrenceChecks(
        field: GeneratedTypeFieldIR,
        valueName: String,
        minOccurs: Int,
        indent: String
    ) -> [String] {
        var lines: [String] = []

        if let maxOccurs = field.maxOccurs, minOccurs == maxOccurs {
            lines.append("\(indent)if \(valueName).count != \(minOccurs) {")
            lines.append("\(indent)    throw SOAPSemanticValidationError(field: \"\(field.name)\", code: \"[CG_SEMANTIC_007]\", message: \"Value count must be exactly \(minOccurs).\")")
            lines.append("\(indent)}")
            return lines
        }

        if minOccurs > 0 {
            lines.append("\(indent)if \(valueName).count < \(minOccurs) {")
            lines.append("\(indent)    throw SOAPSemanticValidationError(field: \"\(field.name)\", code: \"[CG_SEMANTIC_005]\", message: \"Value count is smaller than minOccurs \(minOccurs).\")")
            lines.append("\(indent)}")
        }

        if let maxOccurs = field.maxOccurs {
            lines.append("\(indent)if \(valueName).count > \(maxOccurs) {")
            lines.append("\(indent)    throw SOAPSemanticValidationError(field: \"\(field.name)\", code: \"[CG_SEMANTIC_006]\", message: \"Value count exceeds maxOccurs \(maxOccurs).\")")
            lines.append("\(indent)}")
        }

        return lines
    }

    func emitNumericRangeValidation(
        field: GeneratedTypeFieldIR,
        invalidIf comparisonOperator: String,
        threshold: String,
        diagnosticCode: String,
        message: String
    ) -> [String] {
        guard supportsNumericComparison(field: field) else {
            return []
        }

        let valueName = field.isOptional ? "v" : field.name
        let condition = "\(valueName) \(comparisonOperator) \(threshold)"
        let throwLine = "throw SOAPSemanticValidationError(field: \"\(field.name)\", code: \"\(diagnosticCode)\", message: \"\(message)\")"

        if field.isOptional {
            return [
                "        if let v = \(field.name), \(condition) {",
                "            \(throwLine)",
                "        }"
            ]
        }

        return [
            "        if \(condition) {",
            "            \(throwLine)",
            "        }"
        ]
    }

    func emitTotalDigitsValidation(field: GeneratedTypeFieldIR, constraintValue: String) -> [String] {
        guard let sourceExpression = numericDigitSourceExpression(field: field, valueName: field.isOptional ? "v" : field.name) else {
            return []
        }

        let variableBaseName = validationVariableBaseName(for: field)
        let sourceVariableName = "\(variableBaseName)TotalDigitsSource"
        let countVariableName = "\(variableBaseName)TotalDigitsCount"
        let throwLine = "throw SOAPSemanticValidationError(field: \"\(field.name)\", code: \"[CG_SEMANTIC_010]\", message: \"Value exceeds totalDigits \(constraintValue).\")"

        if field.isOptional {
            return [
                "        if let v = \(field.name) {",
                "            let \(sourceVariableName) = \(sourceExpression)",
                "            let \(countVariableName) = \(sourceVariableName).filter { $0.isNumber }.count",
                "            if \(countVariableName) > \(constraintValue) {",
                "                \(throwLine)",
                "            }",
                "        }"
            ]
        }

        return [
            "        let \(sourceVariableName) = \(sourceExpression)",
            "        let \(countVariableName) = \(sourceVariableName).filter { $0.isNumber }.count",
            "        if \(countVariableName) > \(constraintValue) {",
            "            \(throwLine)",
            "        }"
        ]
    }

    func emitFractionDigitsValidation(field: GeneratedTypeFieldIR, constraintValue: String) -> [String] {
        guard let sourceExpression = numericDigitSourceExpression(field: field, valueName: field.isOptional ? "v" : field.name) else {
            return []
        }

        let variableBaseName = validationVariableBaseName(for: field)
        let sourceVariableName = "\(variableBaseName)FractionDigitsSource"
        let partsVariableName = "\(variableBaseName)FractionDigitsParts"
        let countVariableName = "\(variableBaseName)FractionDigitsCount"
        let throwLine = "throw SOAPSemanticValidationError(field: \"\(field.name)\", code: \"[CG_SEMANTIC_011]\", message: \"Value exceeds fractionDigits \(constraintValue).\")"

        if field.isOptional {
            return [
                "        if let v = \(field.name) {",
                "            let \(sourceVariableName) = \(sourceExpression)",
                "            let \(partsVariableName) = \(sourceVariableName).split(separator: \".\", maxSplits: 1, omittingEmptySubsequences: false)",
                "            let \(countVariableName) = \(partsVariableName).count > 1 ? \(partsVariableName)[1].filter { $0.isNumber }.count : 0",
                "            if \(countVariableName) > \(constraintValue) {",
                "                \(throwLine)",
                "            }",
                "        }"
            ]
        }

        return [
            "        let \(sourceVariableName) = \(sourceExpression)",
            "        let \(partsVariableName) = \(sourceVariableName).split(separator: \".\", maxSplits: 1, omittingEmptySubsequences: false)",
            "        let \(countVariableName) = \(partsVariableName).count > 1 ? \(partsVariableName)[1].filter { $0.isNumber }.count : 0",
            "        if \(countVariableName) > \(constraintValue) {",
            "            \(throwLine)",
            "        }"
        ]
    }

    func supportsNumericComparison(field: GeneratedTypeFieldIR) -> Bool {
        supportedNumericSwiftTypes.contains(field.swiftTypeName)
    }

    func numericDigitSourceExpression(field: GeneratedTypeFieldIR, valueName: String) -> String? {
        guard supportedNumericSwiftTypes.contains(field.swiftTypeName) else {
            return nil
        }

        return "NSDecimalNumber(value: \(valueName)).stringValue.trimmingCharacters(in: CharacterSet(charactersIn: \"+-\"))"
    }

    func validationVariableBaseName(for field: GeneratedTypeFieldIR) -> String {
        let sanitized = field.name.replacingOccurrences(of: "`", with: "")
        return sanitized.isEmpty ? "value" : sanitized
    }

    var supportedNumericSwiftTypes: Set<String> {
        [
            "Double", "Float",
            "Int", "Int8", "Int16", "Int32", "Int64",
            "UInt", "UInt8", "UInt16", "UInt32", "UInt64"
        ]
    }

    func choiceSelectionCountExpression(for field: GeneratedTypeFieldIR) -> String {
        if field.swiftTypeName.hasPrefix("[") {
            return "(\(field.name)?.isEmpty == false ? 1 : 0)"
        }

        return "(\(field.name) != nil ? 1 : 0)"
    }

    func sanitizeEnumCaseName(_ rawValue: String) -> String {
        let tokens = rawValue
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return "unknown" }
        var result = tokens[0].prefix(1).lowercased() + tokens[0].dropFirst()
        if tokens.count > 1 {
            for token in tokens.dropFirst() {
                result += token.prefix(1).uppercased() + token.dropFirst().lowercased()
            }
        }
        if let first = result.first, first.isNumber {
            return "value\(result)"
        }
        let reserved: Set<String> = ["class", "struct", "enum", "protocol", "func", "let", "var", "extension", "default", "case"]
        if reserved.contains(result) {
            return "`\(result)`"
        }
        return result
    }
}

// MARK: - Operation emission

private extension SwiftCodeEmitter {
    func emitOperationEnums(_ service: ServiceIR, port: ServicePortIR) -> [String] {
        var lines: [String] = []
        let identifierEnumName = "\(service.swiftTypeName)\(port.swiftTypeName)OperationIdentifier"
        lines.append("/// Typed operation identifiers for \(service.swiftTypeName).\(port.swiftTypeName).")
        lines.append("public enum \(identifierEnumName): String {")
        for operation in port.operations {
            lines.append("    case \(operation.swiftMethodName) = \"\(operation.operationIdentifierRawValue)\"")
        }
        lines.append("}")
        let actionsOps = port.operations.filter { $0.soapAction != nil }
        if !actionsOps.isEmpty {
            let actionEnumName = "\(service.swiftTypeName)\(port.swiftTypeName)OperationAction"
            lines.append("")
            lines.append("/// Typed SOAP actions for \(service.swiftTypeName).\(port.swiftTypeName).")
            lines.append("public enum \(actionEnumName): String {")
            for op in actionsOps {
                if let soapAction = op.soapAction {
                    lines.append("    case \(op.swiftMethodName) = \"\(soapAction)\"")
                }
            }
            lines.append("}")
        }
        return lines
    }

    func emitOperationContract(
        _ operation: OperationIR,
        identifierEnumName: String,
        actionEnumName: String?
    ) -> [String] {
        var lines: [String] = []
        lines.append("public struct \(operation.operationContractTypeName): SOAPBindingOperationContract {")
        lines.append("    public typealias RequestPayload = \(operation.requestPayloadTypeName)")
        lines.append("    public typealias ResponsePayload = \(operation.responsePayloadTypeName)")
        lines.append("    public typealias FaultDetailPayload = \(operation.faultDetailTypeName)")
        lines.append("")
        lines.append("    public static var operationIdentifier: SOAPOperationIdentifier {")
        lines.append("        SOAPOperationIdentifier(\(identifierEnumName).\(operation.swiftMethodName))")
        lines.append("    }")
        lines.append("")
        lines.append("    public static var soapAction: SOAPAction? {")
        if let actionEnumName = actionEnumName, operation.soapAction != nil {
            lines.append("        SOAPAction(\(actionEnumName).\(operation.swiftMethodName))")
        } else {
            lines.append("        nil")
        }
        lines.append("    }")
        lines.append("")
        lines.append("    public static var bindingMetadata: SOAPBindingMetadata {")
        lines.append("        SOAPBindingMetadata(")
        lines.append("            envelopeVersion: .\(operation.bindingMetadata.envelopeVersion.rawValue),")
        lines.append("            style: .\(operation.bindingMetadata.style.rawValue),")
        lines.append("            bodyUse: .\(operation.bindingMetadata.bodyUse.rawValue)")
        lines.append("        )")
        lines.append("    }")
        lines.append("}")
        return lines
    }
}

// MARK: - Client emission

private extension SwiftCodeEmitter {
    func emitAsyncClientLines(
        service: ServiceIR,
        port: ServicePortIR,
        syntaxProfile: CodeGenerationSyntaxProfile
    ) -> [String] {
        let throwsClause = throwsClause(syntaxProfile: syntaxProfile)
        let clientType = existentialType("SOAPClientAsync", syntaxProfile: syntaxProfile)
        let clientTypeName = "\(service.swiftTypeName)\(port.swiftTypeName)AsyncClient"

        var lines: [String] = []
        lines.append("public struct \(clientTypeName): Sendable {")
        lines.append("    public let client: \(clientType)")
        lines.append("    public let endpointURL: URL")
        lines.append("")
        lines.append("    public init(client: \(clientType), endpointURL: URL) {")
        lines.append("        self.client = client")
        lines.append("        self.endpointURL = endpointURL")
        lines.append("    }")
        lines.append("")
        for operation in port.operations {
            lines.append("    public func \(operation.swiftMethodName)(request: \(operation.requestPayloadTypeName)) async \(throwsClause) -> SOAPOperationResponse<\(operation.responsePayloadTypeName), \(operation.faultDetailTypeName)> {")
            lines.append("        try \(operation.operationContractTypeName).validateBinding()")
            lines.append("        return try await client.invoke(\(operation.operationContractTypeName).self, request: request, endpointURL: endpointURL)")
            lines.append("    }")
            lines.append("")
        }
        lines.append("}")
        return lines
    }

    func emitNIOClientLines(
        service: ServiceIR,
        port: ServicePortIR,
        syntaxProfile: CodeGenerationSyntaxProfile
    ) -> [String] {
        let clientType = existentialType("SOAPClientNIO", syntaxProfile: syntaxProfile)
        let clientTypeName = "\(service.swiftTypeName)\(port.swiftTypeName)NIOClient"

        var lines: [String] = []
        lines.append("public struct \(clientTypeName) {")
        lines.append("    public let client: \(clientType)")
        lines.append("    public let endpointURL: URL")
        lines.append("")
        lines.append("    public init(client: \(clientType), endpointURL: URL) {")
        lines.append("        self.client = client")
        lines.append("        self.endpointURL = endpointURL")
        lines.append("    }")
        lines.append("")
        for operation in port.operations {
            lines.append("    public func \(operation.swiftMethodName)(request: \(operation.requestPayloadTypeName), on eventLoop: EventLoop) -> EventLoopFuture<SOAPOperationResponse<\(operation.responsePayloadTypeName), \(operation.faultDetailTypeName)>> {")
            lines.append("        do {")
            lines.append("            try \(operation.operationContractTypeName).validateBinding()")
            lines.append("        } catch {")
            lines.append("            return eventLoop.makeFailedFuture(error)")
            lines.append("        }")
            lines.append("        return client.invoke(\(operation.operationContractTypeName).self, request: request, endpointURL: endpointURL, on: eventLoop)")
            lines.append("    }")
            lines.append("")
        }
        lines.append("}")
        return lines
    }
}

// MARK: - Server emission

private extension SwiftCodeEmitter {
    func emitAsyncServerLines(
        service: ServiceIR,
        port: ServicePortIR,
        syntaxProfile: CodeGenerationSyntaxProfile
    ) -> [String] {
        let throwsClause = throwsClause(syntaxProfile: syntaxProfile)
        let implementationTypePrefix = existentialTypePrefix(syntaxProfile: syntaxProfile)
        let serverType = existentialType("SOAPServerAsync", syntaxProfile: syntaxProfile)
        let protocolTypeName = "\(service.swiftTypeName)\(port.swiftTypeName)AsyncService"
        let registrarTypeName = "\(service.swiftTypeName)\(port.swiftTypeName)AsyncServerRegistrar"

        var lines: [String] = []
        lines.append("public protocol \(protocolTypeName): Sendable {")
        for operation in port.operations {
            lines.append("    func \(operation.swiftMethodName)(request: \(operation.requestPayloadTypeName)) async \(throwsClause) -> SOAPOperationResponse<\(operation.responsePayloadTypeName), \(operation.faultDetailTypeName)>")
        }
        lines.append("}")
        lines.append("")
        lines.append("public struct \(registrarTypeName): Sendable {")
        lines.append("    public let server: \(serverType)")
        lines.append("")
        lines.append("    public init(server: \(serverType)) {")
        lines.append("        self.server = server")
        lines.append("    }")
        lines.append("")
        lines.append("    public func register(implementation: \(implementationTypePrefix)\(protocolTypeName)) async \(throwsClause) {")
        for operation in port.operations {
            lines.append("        try \(operation.operationContractTypeName).validateBinding()")
            lines.append("        try await server.register(\(operation.operationContractTypeName).self) { request in")
            lines.append("            try await implementation.\(operation.swiftMethodName)(request: request)")
            lines.append("        }")
        }
        lines.append("    }")
        lines.append("}")
        return lines
    }

    func emitNIOServerLines(
        service: ServiceIR,
        port: ServicePortIR,
        syntaxProfile: CodeGenerationSyntaxProfile
    ) -> [String] {
        let implementationTypePrefix = existentialTypePrefix(syntaxProfile: syntaxProfile)
        let serverType = existentialType("SOAPServerNIO", syntaxProfile: syntaxProfile)
        let protocolTypeName = "\(service.swiftTypeName)\(port.swiftTypeName)NIOService"
        let registrarTypeName = "\(service.swiftTypeName)\(port.swiftTypeName)NIOServerRegistrar"

        var lines: [String] = []
        lines.append("public protocol \(protocolTypeName) {")
        for operation in port.operations {
            lines.append("    func \(operation.swiftMethodName)(request: \(operation.requestPayloadTypeName), on eventLoop: EventLoop) -> EventLoopFuture<SOAPOperationResponse<\(operation.responsePayloadTypeName), \(operation.faultDetailTypeName)>>")
        }
        lines.append("}")
        lines.append("")
        lines.append("public struct \(registrarTypeName) {")
        lines.append("    public let server: \(serverType)")
        lines.append("")
        lines.append("    public init(server: \(serverType)) {")
        lines.append("        self.server = server")
        lines.append("    }")
        lines.append("")
        lines.append("    public func register(implementation: \(implementationTypePrefix)\(protocolTypeName)) {")
        for operation in port.operations {
            lines.append("        server.register(\(operation.operationContractTypeName).self) { request, eventLoop in")
            lines.append("            do {")
            lines.append("                try \(operation.operationContractTypeName).validateBinding()")
            lines.append("            } catch {")
            lines.append("                return eventLoop.makeFailedFuture(error)")
            lines.append("            }")
            lines.append("            return implementation.\(operation.swiftMethodName)(request: request, on: eventLoop)")
            lines.append("        }")
        }
        lines.append("    }")
        lines.append("}")
        return lines
    }
}

// MARK: - Helpers

private extension SwiftCodeEmitter {
    func throwsClause(syntaxProfile: CodeGenerationSyntaxProfile) -> String {
        syntaxProfile.useTypedThrowsAnyError ? "throws(any Error)" : "throws"
    }

    func existentialType(_ protocolName: String, syntaxProfile: CodeGenerationSyntaxProfile) -> String {
        "\(existentialTypePrefix(syntaxProfile: syntaxProfile))\(protocolName)"
    }

    func existentialTypePrefix(syntaxProfile: CodeGenerationSyntaxProfile) -> String {
        syntaxProfile.useExistentialAny ? "any " : ""
    }
}
