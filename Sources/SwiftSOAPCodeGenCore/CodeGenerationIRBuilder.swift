import Foundation
import SwiftSOAPWSDL
// swiftlint:disable file_length

// MARK: - Architecture: WSDL → IR pipeline
//
// `CodeGenerationIRBuilder` transforms a parsed `WSDLDefinition` into a
// `SOAPCodeGenerationIR`, the language-neutral intermediate representation
// consumed by `SwiftCodeEmitter` to produce Swift source files.
//
// ## Pipeline stages
//
//   build(from: WSDLDefinition, configuration:)
//     │
//     ├─ buildMessagePayloadTypes   → one GeneratedTypeIR per WSDL <message>
//     │    Each message becomes a Swift struct conforming to SOAPBodyPayload,
//     │    with one optional field per message <part>.
//     │
//     ├─ buildSchemaTypes           → one GeneratedTypeIR per <complexType> in <types>
//     │    XSD sequence elements → required/optional fields (minOccurs drives optionality)
//     │    XSD choice groups     → optional fields + group metadata for validation
//     │    XSD attributes        → XML attribute-mapped fields, including attributeGroup reuse
//     │    XSD simpleContent     → text-backed field + attribute flattening
//     │
//     └─ buildServiceIR (per service)
//          └─ buildPortIR (per port) → resolves binding → resolves portType
//               └─ buildOperationIR (per operation)
//                    Resolves input/output/fault message references,
//                    produces ServiceOperationIR with request/response/fault type names.
//
// ## Name sanitisation
//
// Swift identifier rules differ from WSDL/XSD naming (hyphens, leading digits,
// reserved words).  `sanitizeTypeName` and `sanitizePropertyName` normalise names
// to valid lowerCamelCase / UpperCamelCase Swift identifiers.  When a name is
// changed, the original XML name is preserved in `xmlName` so the emitter can
// emit the correct CodingKey mapping.
//
// ## Symbol uniqueness
//
// `generatedTypeNames` (inout Set) tracks all emitted Swift type names across the
// full build to prevent collisions.  `ensureUniqueSymbol` throws if a name would
// be duplicated, surfacing the conflict as a diagnostics error.
public struct CodeGenerationIRBuilder {
    private struct ResolvedComplexTypeContent {
        var sequence: [WSDLDefinition.Element] = []
        var choiceGroups: [WSDLDefinition.ChoiceGroup] = []
        var attributes: [WSDLDefinition.Attribute] = []
    }

    private struct ResolvedSimpleContent {
        let valueTypeQName: WSDLDefinition.QName
        var attributes: [WSDLDefinition.Attribute]
    }

    private struct SchemaGenerationArtifacts {
        let generatedProtocols: [GeneratedProtocolIR]
        let generatedTypes: [GeneratedTypeIR]
    }

    private struct GeneratedFieldArtifacts {
        let fields: [GeneratedTypeFieldIR]
        let choiceGroups: [GeneratedChoiceGroupIR]
    }

    private struct SchemaProtocolDescriptor {
        let protocolName: String
        let inheritedProtocolNames: [String]
        let fields: [GeneratedTypeFieldIR]
    }

    private struct ComplexTypeKey: Hashable {
        let name: String
        let namespaceURI: String?
    }

    private struct AttributeGroupKey: Hashable {
        let name: String
        let namespaceURI: String?
    }

    private struct OccurrenceBounds {
        let minOccurs: Int
        let maxOccurs: Int?
    }

    public init() {}

    public func build(from definition: WSDLDefinition, configuration: CodeGenConfiguration) throws -> SOAPCodeGenerationIR {
        var generatedProtocols: [GeneratedProtocolIR] = []
        var generatedTypes: [GeneratedTypeIR] = []
        var generatedTypeNames = Set<String>()

        let messagesByName = Dictionary(uniqueKeysWithValues: definition.messages.map { ($0.name, $0) })
        let portTypesByName = Dictionary(uniqueKeysWithValues: definition.portTypes.map { ($0.name, $0) })
        let bindingsByName = Dictionary(uniqueKeysWithValues: definition.bindings.map { ($0.name, $0) })

        let messageTypes = try buildMessagePayloadTypes(
            messages: definition.messages,
            types: definition.types,
            generatedTypeNames: &generatedTypeNames
        )
        generatedTypes.append(contentsOf: messageTypes)

        let schemaArtifacts = try buildSchemaTypes(types: definition.types, generatedTypeNames: &generatedTypeNames)
        generatedProtocols.append(contentsOf: schemaArtifacts.generatedProtocols)
        generatedTypes.append(contentsOf: schemaArtifacts.generatedTypes)

        let services = try definition.services.map { service in
            try buildServiceIR(
                service: service,
                messagesByName: messagesByName,
                portTypesByName: portTypesByName,
                bindingsByName: bindingsByName,
                generatedTypes: &generatedTypes,
                generatedTypeNames: &generatedTypeNames
            )
        }

        return SOAPCodeGenerationIR(
            moduleName: sanitizeTypeName(configuration.moduleName),
            generationScope: configuration.generationScope,
            runtimeTargets: configuration.runtimeTargets,
            apiStyle: configuration.apiStyle,
            generatedProtocols: generatedProtocols,
            generatedTypes: generatedTypes,
            services: services,
            validationProfile: configuration.validationProfile
        )
    }
}

private extension CodeGenerationIRBuilder {
    private func buildMessagePayloadTypes(
        messages: [WSDLDefinition.Message],
        types: WSDLDefinition.Types,
        generatedTypeNames: inout Set<String>
    ) throws -> [GeneratedTypeIR] {
        return try messages.map { message in
            let payloadTypeName = sanitizeTypeName("\(message.name)Payload")
            try ensureUniqueSymbol(payloadTypeName, generatedTypeNames: &generatedTypeNames)

            var resolvedNamespaceURI: String?
            var choiceGroups: [GeneratedChoiceGroupIR] = []
            let fields = try message.parts.flatMap { part -> [GeneratedTypeFieldIR] in
                if let resolvedElement = findSchemaElement(
                    named: part.elementQName?.localName ?? part.elementName,
                    namespaceURI: part.elementQName?.namespaceURI,
                    in: types
                ) {
                    if resolvedNamespaceURI == nil {
                        resolvedNamespaceURI = resolvedElement.namespaceURI
                    }

                    if let payloadArtifacts = try payloadFields(for: resolvedElement.element, types: types) {
                        choiceGroups.append(contentsOf: payloadArtifacts.choiceGroups)
                        return payloadArtifacts.fields
                    }
                }

                return [messagePartField(for: part)]
            }

            // Doc/literal single-part: the element local name is the XML root element name.
            let xmlRootElementName: String? = message.parts.count == 1
                ? message.parts[0].elementName
                : nil

            return GeneratedTypeIR(
                swiftTypeName: payloadTypeName,
                kind: .bodyPayload,
                fields: fields,
                choiceGroups: choiceGroups,
                xmlRootElementName: xmlRootElementName,
                xmlRootElementNamespaceURI: xmlRootElementName != nil ? resolvedNamespaceURI : nil
            )
        }
    }

    private func buildSchemaTypes(
        types: WSDLDefinition.Types,
        generatedTypeNames: inout Set<String>
    ) throws -> SchemaGenerationArtifacts {
        let protocolDescriptors = try makeSchemaProtocolDescriptors(types: types)
        var generatedProtocols: [GeneratedProtocolIR] = []
        var generatedTypes: [GeneratedTypeIR] = []

        for schema in types.schemas {
            for complexType in schema.complexTypes {
                let complexTypeKey = ComplexTypeKey(name: complexType.name, namespaceURI: schema.targetNamespace)
                let protocolDescriptor = protocolDescriptors[complexTypeKey]
                if let protocolDescriptor = protocolDescriptor {
                    try ensureUniqueSymbol(protocolDescriptor.protocolName, generatedTypeNames: &generatedTypeNames)
                    generatedProtocols.append(
                        GeneratedProtocolIR(
                            swiftTypeName: protocolDescriptor.protocolName,
                            inheritedProtocolNames: protocolDescriptor.inheritedProtocolNames,
                            fields: protocolDescriptor.fields
                        )
                    )
                }

                let schemaSwiftTypeName = sanitizeTypeName(complexType.name)
                try ensureUniqueSymbol(schemaSwiftTypeName, generatedTypeNames: &generatedTypeNames)
                let fieldArtifacts: GeneratedFieldArtifacts
                if complexType.simpleContentBaseQName != nil {
                    var visitedTypeNames = Set<String>()
                    let resolvedContent = try resolveSimpleContent(
                        complexType,
                        types: types,
                        visitedTypeNames: &visitedTypeNames
                    )
                    fieldArtifacts = buildSimpleContentFieldArtifacts(
                        valueTypeQName: resolvedContent.valueTypeQName,
                        attributes: resolvedContent.attributes
                    )
                } else {
                    var visitedTypeNames = Set<String>()
                    let resolvedContent = try resolveComplexTypeContent(
                        complexType,
                        types: types,
                        visitedTypeNames: &visitedTypeNames
                    )
                    fieldArtifacts = buildFieldArtifacts(
                        sequence: resolvedContent.sequence,
                        choiceGroups: resolvedContent.choiceGroups,
                        attributes: resolvedContent.attributes,
                        types: types
                    )
                }

                generatedTypes.append(
                    GeneratedTypeIR(
                        swiftTypeName: schemaSwiftTypeName,
                        kind: .schemaModel,
                        protocolConformances: protocolDescriptor.map { [$0.protocolName] } ?? [],
                        fields: fieldArtifacts.fields,
                        choiceGroups: fieldArtifacts.choiceGroups
                    )
                )
            }

            for simpleType in schema.simpleTypes {
                let schemaSwiftTypeName = sanitizeTypeName(simpleType.name)
                try ensureUniqueSymbol(schemaSwiftTypeName, generatedTypeNames: &generatedTypeNames)

                if !simpleType.enumerationValues.isEmpty {
                    generatedTypes.append(
                        GeneratedTypeIR(
                            swiftTypeName: schemaSwiftTypeName,
                            kind: .enumeration,
                            fields: [],
                            enumerationCases: simpleType.enumerationValues
                        )
                    )
                } else {
                    let fieldTypeName = swiftTypeName(forQNameLocalName: simpleType.baseQName?.localName)
                    let constraints = facetConstraints(from: simpleType.facets)
                    let fields = [
                        GeneratedTypeFieldIR(
                            name: "rawValue",
                            swiftTypeName: fieldTypeName,
                            isOptional: false,
                            xmlFieldKind: .text,
                            xmlOrder: 0,
                            constraints: constraints
                        )
                    ]
                    generatedTypes.append(
                        GeneratedTypeIR(
                            swiftTypeName: schemaSwiftTypeName,
                            kind: .schemaModel,
                            fields: fields
                        )
                    )
                }
            }
        }

        return SchemaGenerationArtifacts(
            generatedProtocols: generatedProtocols,
            generatedTypes: generatedTypes
        )
    }

    private func payloadFields(
        for element: WSDLDefinition.Element,
        types: WSDLDefinition.Types
    ) throws -> GeneratedFieldArtifacts? {
        if !element.inlineSequenceElements.isEmpty {
            return buildFieldArtifacts(
                sequence: element.inlineSequenceElements,
                choiceGroups: [],
                attributes: [],
                types: types
            )
        }

        guard let typeQName = element.typeQName,
              let complexType = findComplexType(
                  named: typeQName.localName,
                  namespaceURI: typeQName.namespaceURI,
                  in: types
              ) else {
            return nil
        }

        if complexType.simpleContentBaseQName != nil {
            var visitedTypeNames = Set<String>()
            let resolvedContent = try resolveSimpleContent(
                complexType,
                types: types,
                visitedTypeNames: &visitedTypeNames
            )
            return buildSimpleContentFieldArtifacts(
                valueTypeQName: resolvedContent.valueTypeQName,
                attributes: resolvedContent.attributes
            )
        }

        var visitedTypeNames = Set<String>()
        let resolvedContent = try resolveComplexTypeContent(
            complexType,
            types: types,
            visitedTypeNames: &visitedTypeNames
        )
        return buildFieldArtifacts(
            sequence: resolvedContent.sequence,
            choiceGroups: resolvedContent.choiceGroups,
            attributes: resolvedContent.attributes,
            types: types
        )
    }

    private func buildFieldArtifacts(
        sequence: [WSDLDefinition.Element],
        choiceGroups: [WSDLDefinition.ChoiceGroup],
        attributes: [WSDLDefinition.Attribute],
        types: WSDLDefinition.Types
    ) -> GeneratedFieldArtifacts {
        var fields: [GeneratedTypeFieldIR] = []
        var emittedChoiceGroups: [GeneratedChoiceGroupIR] = []
        var xmlOrder = 0

        for element in sequence {
            fields.append(schemaField(for: element, types: types, isChoiceField: false, xmlOrder: xmlOrder))
            xmlOrder += 1
        }

        for choiceGroup in choiceGroups {
            var groupFields: [GeneratedTypeFieldIR] = []
            for element in choiceGroup.elements {
                groupFields.append(schemaField(for: element, types: types, isChoiceField: true, xmlOrder: xmlOrder))
                xmlOrder += 1
            }

            fields.append(contentsOf: groupFields)

            if !groupFields.isEmpty {
                let bounds = choiceGroupBounds(for: choiceGroup)
                emittedChoiceGroups.append(
                    GeneratedChoiceGroupIR(
                        fieldNames: groupFields.map(\.name),
                        minOccurs: bounds.minOccurs,
                        maxOccurs: bounds.maxOccurs
                    )
                )
            }
        }

        fields.append(contentsOf: attributes.map { attributeField(for: $0) })
        return GeneratedFieldArtifacts(fields: fields, choiceGroups: emittedChoiceGroups)
    }

    private func buildSimpleContentFieldArtifacts(
        valueTypeQName: WSDLDefinition.QName,
        attributes: [WSDLDefinition.Attribute]
    ) -> GeneratedFieldArtifacts {
        let valueFieldName = simpleContentValueFieldName(for: attributes)
        var fields = [
            GeneratedTypeFieldIR(
                name: valueFieldName,
                swiftTypeName: swiftTypeName(forQNameLocalName: valueTypeQName.localName),
                isOptional: false,
                xmlFieldKind: .text,
                xmlOrder: 0
            )
        ]

        for (index, attribute) in attributes.enumerated() {
            fields.append(attributeField(for: attribute, xmlOrder: index + 1))
        }

        return GeneratedFieldArtifacts(fields: fields, choiceGroups: [])
    }

    private func buildServiceIR(
        service: WSDLDefinition.Service,
        messagesByName: [String: WSDLDefinition.Message],
        portTypesByName: [String: WSDLDefinition.PortType],
        bindingsByName: [String: WSDLDefinition.Binding],
        generatedTypes: inout [GeneratedTypeIR],
        generatedTypeNames: inout Set<String>
    ) throws -> ServiceIR {
        let serviceTypeName = sanitizeTypeName(service.name)
        let ports = try service.ports.map { port in
            try buildPortIR(
                serviceName: service.name,
                port: port,
                messagesByName: messagesByName,
                portTypesByName: portTypesByName,
                bindingsByName: bindingsByName,
                generatedTypes: &generatedTypes,
                generatedTypeNames: &generatedTypeNames
            )
        }

        return ServiceIR(swiftTypeName: serviceTypeName, ports: ports)
    }

    private func buildPortIR(
        serviceName: String,
        port: WSDLDefinition.ServicePort,
        messagesByName: [String: WSDLDefinition.Message],
        portTypesByName: [String: WSDLDefinition.PortType],
        bindingsByName: [String: WSDLDefinition.Binding],
        generatedTypes: inout [GeneratedTypeIR],
        generatedTypeNames: inout Set<String>
    ) throws -> ServicePortIR {
        guard let bindingName = port.bindingName, let binding = bindingsByName[bindingName] else {
            throw CodeGenError(
                code: .unresolvedReference,
                message: "Service port '\(serviceName).\(port.name)' references unknown binding '\(port.bindingName ?? "<nil>")'."
            )
        }

        guard let portTypeName = binding.typeName, let portType = portTypesByName[portTypeName] else {
            throw CodeGenError(
                code: .unresolvedReference,
                message: "Binding '\(binding.name)' references unknown portType '\(binding.typeName ?? "<nil>")'."
            )
        }

        let bindingOperationsByName = Dictionary(uniqueKeysWithValues: binding.operations.map { ($0.name, $0) })

        let operations = try portType.operations.map { operation -> OperationIR in
            let bindingOperation = bindingOperationsByName[operation.name]
            return try buildOperationIR(
                serviceName: serviceName,
                portName: port.name,
                binding: binding,
                bindingOperation: bindingOperation,
                operation: operation,
                messagesByName: messagesByName,
                generatedTypes: &generatedTypes,
                generatedTypeNames: &generatedTypeNames
            )
        }

        return ServicePortIR(swiftTypeName: sanitizeTypeName(port.name), operations: operations)
    }

    private func buildOperationIR(
        serviceName: String,
        portName: String,
        binding: WSDLDefinition.Binding,
        bindingOperation: WSDLDefinition.BindingOperation?,
        operation: WSDLDefinition.Operation,
        messagesByName: [String: WSDLDefinition.Message],
        generatedTypes: inout [GeneratedTypeIR],
        generatedTypeNames: inout Set<String>
    ) throws -> OperationIR {
        let requestTypeName = payloadTypeName(forMessageName: operation.inputMessageName)
        let responseTypeName = payloadTypeName(forMessageName: operation.outputMessageName) ?? "SOAPEmptyPayload"

        if let inputMessageName = operation.inputMessageName {
            guard messagesByName[inputMessageName] != nil else {
                throw CodeGenError(
                    code: .unresolvedReference,
                    message: "Operation '\(operation.name)' references unknown input message '\(inputMessageName)'."
                )
            }
        }

        if let outputMessageName = operation.outputMessageName {
            guard messagesByName[outputMessageName] != nil else {
                throw CodeGenError(
                    code: .unresolvedReference,
                    message: "Operation '\(operation.name)' references unknown output message '\(outputMessageName)'."
                )
            }
        }

        let faultDetailTypeName: String
        if let firstFaultMessageName = operation.faults.first?.messageName {
            guard let faultMessage = messagesByName[firstFaultMessageName] else {
                throw CodeGenError(
                    code: .unresolvedReference,
                    message: "Operation '\(operation.name)' references unknown fault message '\(firstFaultMessageName)'."
                )
            }

            let faultTypeName = faultDetailPayloadTypeName(forMessageName: firstFaultMessageName)
            if !generatedTypeNames.contains(faultTypeName) {
                generatedTypeNames.insert(faultTypeName)
                generatedTypes.append(
                    GeneratedTypeIR(
                        swiftTypeName: faultTypeName,
                        kind: .faultDetailPayload,
                        fields: faultMessage.parts.map { part in
                            let swiftName = sanitizePropertyName(part.name)
                            let xmlNameValue = part.name != swiftName ? part.name : nil
                            return GeneratedTypeFieldIR(
                                name: swiftName,
                                swiftTypeName: swiftTypeName(forQNameLocalName: part.typeName),
                                isOptional: true,
                                xmlName: xmlNameValue
                            )
                        }
                    )
                )
            }
            faultDetailTypeName = faultTypeName
        } else {
            faultDetailTypeName = "SOAPEmptyFaultDetailPayload"
        }

        guard let resolvedBindingMetadata = resolveBindingMetadata(binding: binding, operation: bindingOperation) else {
            throw CodeGenError(
                code: .unsupportedBinding,
                message: "Unable to resolve binding metadata for operation '\(serviceName).\(portName).\(operation.name)'.",
                suggestion: "Ensure style/use/version are valid SOAP values."
            )
        }

        let mep: SOAPCodeGenerationMEP
        if operation.inputMessageName != nil && operation.outputMessageName != nil {
            mep = .requestResponse
        } else if operation.inputMessageName != nil && operation.outputMessageName == nil {
            mep = .oneWay
        } else {
            throw CodeGenError(
                code: .invalidInput,
                message: "Operation '\(serviceName).\(portName).\(operation.name)' has an unsupported MEP (e.g. notification).",
                suggestion: "Only request-response and one-way operations are supported."
            )
        }

        let operationContractTypeName = sanitizeTypeName("\(serviceName)\(portName)\(operation.name)Operation")
        try ensureUniqueSymbol(operationContractTypeName, generatedTypeNames: &generatedTypeNames)

        return OperationIR(
            swiftMethodName: sanitizePropertyName(operation.name),
            operationContractTypeName: operationContractTypeName,
            operationIdentifierRawValue: "\(serviceName).\(portName).\(operation.name)",
            requestPayloadTypeName: requestTypeName ?? "SOAPEmptyPayload",
            responsePayloadTypeName: responseTypeName,
            faultDetailTypeName: faultDetailTypeName,
            soapAction: bindingOperation?.soapAction,
            bindingMetadata: resolvedBindingMetadata,
            messageExchangePattern: mep
        )
    }

    private func resolveBindingMetadata(
        binding: WSDLDefinition.Binding,
        operation: WSDLDefinition.BindingOperation?
    ) -> BindingMetadataIR? {
        let envelopeVersion = binding.soapVersion ?? .soap11
        let style = operation?.styleKind ?? binding.styleKind ?? .document

        let bodyUse: WSDLDefinition.SOAPBodyUse
        if let operationUse = operation?.inputUseKind ?? operation?.outputUseKind {
            bodyUse = operationUse
        } else {
            bodyUse = .literal
        }

        return BindingMetadataIR(envelopeVersion: envelopeVersion, style: style, bodyUse: bodyUse)
    }

    private func payloadTypeName(forMessageName messageName: String?) -> String? {
        guard let messageName = messageName else {
            return nil
        }
        return sanitizeTypeName("\(messageName)Payload")
    }

    private func faultDetailPayloadTypeName(forMessageName messageName: String) -> String {
        return sanitizeTypeName("\(messageName)FaultDetail")
    }

    private func swiftTypeName(forQNameLocalName localName: String?) -> String {
        guard let localName = localName else {
            return "String"
        }

        switch localName {
        case "string":
            return "String"
        case "boolean":
            return "Bool"
        case "int", "integer", "long", "short", "byte":
            return "Int"
        case "float", "double", "decimal":
            return "Double"
        default:
            return sanitizeTypeName(localName)
        }
    }

    private func facetConstraints(from facets: WSDLDefinition.Facets?) -> [FacetConstraintIR] {
        guard let facets = facets else { return [] }
        var result: [FacetConstraintIR] = []
        if let value = facets.pattern { result.append(FacetConstraintIR(kind: .pattern, value: value)) }
        if let value = facets.minLength { result.append(FacetConstraintIR(kind: .minLength, value: String(value))) }
        if let value = facets.maxLength { result.append(FacetConstraintIR(kind: .maxLength, value: String(value))) }
        if let value = facets.length { result.append(FacetConstraintIR(kind: .length, value: String(value))) }
        if let value = facets.minInclusive { result.append(FacetConstraintIR(kind: .minInclusive, value: value)) }
        if let value = facets.maxInclusive { result.append(FacetConstraintIR(kind: .maxInclusive, value: value)) }
        if let value = facets.minExclusive { result.append(FacetConstraintIR(kind: .minExclusive, value: value)) }
        if let value = facets.maxExclusive { result.append(FacetConstraintIR(kind: .maxExclusive, value: value)) }
        if let value = facets.totalDigits { result.append(FacetConstraintIR(kind: .totalDigits, value: String(value))) }
        if let value = facets.fractionDigits { result.append(FacetConstraintIR(kind: .fractionDigits, value: String(value))) }
        return result
    }

    private func ensureUniqueSymbol(_ symbol: String, generatedTypeNames: inout Set<String>) throws {
        if generatedTypeNames.contains(symbol) {
            throw CodeGenError(code: .duplicateSymbol, message: "Duplicated generated symbol '\(symbol)'.")
        }
        generatedTypeNames.insert(symbol)
    }

    private func generatedProtocolName(forTypeName typeName: String) -> String {
        "\(typeName)Protocol"
    }

    private func sanitizeTypeName(_ value: String) -> String {
        let alphaNumeric = value
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map { token in token.prefix(1).uppercased() + token.dropFirst() }
            .joined()

        if alphaNumeric.isEmpty {
            return "GeneratedType"
        }

        if let firstCharacter = alphaNumeric.first, firstCharacter.isNumber {
            return "Type\(alphaNumeric)"
        }

        return alphaNumeric
    }

    private func sanitizePropertyName(_ value: String) -> String {
        let tokens = value
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !$0.isEmpty }

        if tokens.isEmpty {
            return "value"
        }

        var result = tokens[0].prefix(1).lowercased() + tokens[0].dropFirst()
        if tokens.count > 1 {
            for token in tokens.dropFirst() {
                result += token.prefix(1).uppercased() + token.dropFirst().lowercased()
            }
        }

        if let firstCharacter = result.first, firstCharacter.isNumber {
            return "value\(result)"
        }

        let reserved: Set<String> = [
            "associatedtype", "break", "case", "catch", "class", "continue", "default",
            "defer", "deinit", "do", "else", "enum", "extension", "fallthrough", "false",
            "for", "func", "guard", "if", "import", "in", "init", "inout", "internal",
            "is", "let", "nil", "operator", "private", "protocol", "public", "repeat",
            "rethrows", "return", "self", "Self", "static", "struct", "subscript", "super",
            "switch", "throw", "throws", "true", "try", "typealias", "var", "where", "while"
        ]

        if reserved.contains(result) {
            return "`\(result)`"
        }

        return result
    }

    private func messagePartField(for part: WSDLDefinition.Part) -> GeneratedTypeFieldIR {
        let swiftName = sanitizePropertyName(part.name)
        let xmlNameValue = part.name != swiftName ? part.name : nil
        return GeneratedTypeFieldIR(
            name: swiftName,
            swiftTypeName: swiftTypeName(forQNameLocalName: part.typeName),
            isOptional: true,
            xmlName: xmlNameValue
        )
    }

    private func schemaField(
        for element: WSDLDefinition.Element,
        types: WSDLDefinition.Types,
        isChoiceField: Bool,
        xmlOrder: Int
    ) -> GeneratedTypeFieldIR {
        let swiftName = sanitizePropertyName(element.name)
        let xmlNameValue = element.name != swiftName ? element.name : nil
        let occurrenceBounds = occurrenceBounds(for: element)
        return GeneratedTypeFieldIR(
            name: swiftName,
            swiftTypeName: swiftTypeName(for: element, types: types),
            isOptional: isChoiceField || isOptional(element),
            minOccurs: occurrenceBounds?.minOccurs,
            maxOccurs: occurrenceBounds?.maxOccurs,
            xmlName: xmlNameValue,
            xmlOrder: xmlOrder
        )
    }

    private func attributeField(
        for attribute: WSDLDefinition.Attribute,
        xmlOrder: Int? = nil
    ) -> GeneratedTypeFieldIR {
        let swiftName = sanitizePropertyName(attribute.name)
        let xmlNameValue = attribute.name != swiftName ? attribute.name : nil
        return GeneratedTypeFieldIR(
            name: swiftName,
            swiftTypeName: swiftTypeName(forQNameLocalName: attribute.typeQName?.localName),
            isOptional: attribute.use != "required",
            xmlFieldKind: .attribute,
            xmlName: xmlNameValue,
            xmlOrder: xmlOrder
        )
    }

    private func swiftTypeName(
        for element: WSDLDefinition.Element,
        types: WSDLDefinition.Types
    ) -> String {
        let resolvedTypeQName = element.typeQName ?? referencedElement(for: element, in: types)?.typeQName
        let resolvedTypeName = swiftTypeName(forQNameLocalName: resolvedTypeQName?.localName)
        if isRepeated(element) {
            return "[\(resolvedTypeName)]"
        }
        return resolvedTypeName
    }

    private func isOptional(_ element: WSDLDefinition.Element) -> Bool {
        element.minOccurs == 0 || element.nillable
    }

    private func isRepeated(_ element: WSDLDefinition.Element) -> Bool {
        guard let maxOccurs = element.maxOccurs else {
            return false
        }

        if maxOccurs == "unbounded" {
            return true
        }

        return Int(maxOccurs).map { $0 > 1 } ?? false
    }

    private func occurrenceBounds(for element: WSDLDefinition.Element) -> OccurrenceBounds? {
        guard isRepeated(element) else {
            return nil
        }

        let minOccurs = element.minOccurs ?? 1
        let maxOccurs: Int?
        if let rawMaxOccurs = element.maxOccurs, rawMaxOccurs != "unbounded" {
            maxOccurs = Int(rawMaxOccurs)
        } else {
            maxOccurs = nil
        }

        return OccurrenceBounds(minOccurs: minOccurs, maxOccurs: maxOccurs)
    }

    private func choiceGroupBounds(for choiceGroup: WSDLDefinition.ChoiceGroup) -> OccurrenceBounds {
        let minOccurs = choiceGroup.minOccurs ?? 1
        let maxOccurs: Int?
        if let rawMaxOccurs = choiceGroup.maxOccurs {
            maxOccurs = rawMaxOccurs == "unbounded" ? nil : Int(rawMaxOccurs)
        } else {
            maxOccurs = 1
        }

        return OccurrenceBounds(minOccurs: minOccurs, maxOccurs: maxOccurs)
    }

    private func resolveComplexTypeContent(
        _ complexType: WSDLDefinition.ComplexType,
        types: WSDLDefinition.Types,
        visitedTypeNames: inout Set<String>
    ) throws -> ResolvedComplexTypeContent {
        guard visitedTypeNames.insert(complexType.name).inserted else {
            throw CodeGenError(
                code: .invalidInput,
                message: "Cyclic complexType extension hierarchy detected for '\(complexType.name)'."
            )
        }

        defer { visitedTypeNames.remove(complexType.name) }

        var content = ResolvedComplexTypeContent()
        if let baseQName = complexType.baseQName {
            guard let baseType = findComplexType(
                named: baseQName.localName,
                namespaceURI: baseQName.namespaceURI,
                in: types
            ) else {
                throw CodeGenError(
                    code: .unresolvedReference,
                    message: "complexType '\(complexType.name)' extends unknown base type '\(baseQName.rawValue)'."
                )
            }
            content = try resolveComplexTypeContent(
                baseType,
                types: types,
                visitedTypeNames: &visitedTypeNames
            )
        }

        content.sequence.append(contentsOf: complexType.sequence)
        content.choiceGroups.append(contentsOf: complexType.choiceGroups)
        content.attributes.append(contentsOf: try resolveDeclaredAttributes(for: complexType, types: types))
        return content
    }

    private func resolveSimpleContent(
        _ complexType: WSDLDefinition.ComplexType,
        types: WSDLDefinition.Types,
        visitedTypeNames: inout Set<String>
    ) throws -> ResolvedSimpleContent {
        guard visitedTypeNames.insert(complexType.name).inserted else {
            throw CodeGenError(
                code: .invalidInput,
                message: "Cyclic simpleContent extension hierarchy detected for '\(complexType.name)'."
            )
        }

        defer { visitedTypeNames.remove(complexType.name) }

        guard let baseQName = complexType.simpleContentBaseQName else {
            throw CodeGenError(
                code: .invalidInput,
                message: "complexType '\(complexType.name)' does not declare simpleContent."
            )
        }

        if let baseComplexType = findComplexType(
            named: baseQName.localName,
            namespaceURI: baseQName.namespaceURI,
            in: types
        ) {
            guard baseComplexType.simpleContentBaseQName != nil else {
                throw CodeGenError(
                    code: .invalidInput,
                    message: "simpleContent type '\(complexType.name)' extends non-simpleContent complexType '\(baseQName.rawValue)'."
                )
            }

            var resolved = try resolveSimpleContent(
                baseComplexType,
                types: types,
                visitedTypeNames: &visitedTypeNames
            )
            resolved.attributes.append(contentsOf: try resolveDeclaredAttributes(for: complexType, types: types))
            return resolved
        }

        return ResolvedSimpleContent(
            valueTypeQName: baseQName,
            attributes: try resolveDeclaredAttributes(for: complexType, types: types)
        )
    }

    private func resolveDeclaredAttributes(
        for complexType: WSDLDefinition.ComplexType,
        types: WSDLDefinition.Types
    ) throws -> [WSDLDefinition.Attribute] {
        var resolvedAttributes = complexType.attributes
        for attributeRef in complexType.attributeRefs {
            resolvedAttributes.append(try resolveAttributeReference(attributeRef, types: types))
        }
        for attributeGroupRef in complexType.attributeGroupRefs {
            var visitedGroupKeys = Set<AttributeGroupKey>()
            resolvedAttributes.append(
                contentsOf: try resolveAttributeGroupAttributes(
                    attributeGroupRef,
                    types: types,
                    visitedGroupKeys: &visitedGroupKeys
                )
            )
        }
        return resolvedAttributes
    }

    private func resolveAttributeReference(
        _ attributeReference: WSDLDefinition.AttributeReference,
        types: WSDLDefinition.Types
    ) throws -> WSDLDefinition.Attribute {
        guard let attributeDefinition = findAttributeDefinition(
            named: attributeReference.refQName.localName,
            namespaceURI: attributeReference.refQName.namespaceURI,
            in: types
        ) else {
            throw CodeGenError(
                code: .unresolvedReference,
                message: "attribute reference '\(attributeReference.refQName.rawValue)' could not be resolved."
            )
        }

        return WSDLDefinition.Attribute(
            name: attributeDefinition.name,
            typeQName: attributeDefinition.typeQName,
            use: attributeReference.use ?? attributeDefinition.use
        )
    }

    private func resolveAttributeGroupAttributes(
        _ qName: WSDLDefinition.QName,
        types: WSDLDefinition.Types,
        visitedGroupKeys: inout Set<AttributeGroupKey>
    ) throws -> [WSDLDefinition.Attribute] {
        guard let attributeGroupKey = findAttributeGroupKey(
            named: qName.localName,
            namespaceURI: qName.namespaceURI,
            in: types
        ) else {
            throw CodeGenError(
                code: .unresolvedReference,
                message: "attributeGroup reference '\(qName.rawValue)' could not be resolved."
            )
        }

        guard visitedGroupKeys.insert(attributeGroupKey).inserted else {
            throw CodeGenError(
                code: .invalidInput,
                message: "Cyclic attributeGroup reference detected for '\(attributeGroupKey.name)'."
            )
        }

        defer { visitedGroupKeys.remove(attributeGroupKey) }

        guard let attributeGroup = findAttributeGroup(
            named: attributeGroupKey.name,
            namespaceURI: attributeGroupKey.namespaceURI,
            in: types
        ) else {
            throw CodeGenError(
                code: .unresolvedReference,
                message: "attributeGroup reference '\(qName.rawValue)' could not be resolved."
            )
        }

        var resolvedAttributes = attributeGroup.attributes
        for attributeRef in attributeGroup.attributeRefs {
            resolvedAttributes.append(try resolveAttributeReference(attributeRef, types: types))
        }
        for nestedReference in attributeGroup.attributeGroupRefs {
            resolvedAttributes.append(
                contentsOf: try resolveAttributeGroupAttributes(
                    nestedReference,
                    types: types,
                    visitedGroupKeys: &visitedGroupKeys
                )
            )
        }
        return resolvedAttributes
    }

    private func findSchemaElement(
        named localName: String?,
        namespaceURI: String?,
        in types: WSDLDefinition.Types
    ) -> (element: WSDLDefinition.Element, namespaceURI: String?)? {
        guard let localName = localName else {
            return nil
        }

        if let namespaceURI = namespaceURI {
            for schema in types.schemas where schema.targetNamespace == namespaceURI {
                if let element = schema.elements.first(where: { $0.name == localName }) {
                    return (element, schema.targetNamespace)
                }
            }
        }

        for schema in types.schemas {
            if let element = schema.elements.first(where: { $0.name == localName }) {
                return (element, schema.targetNamespace)
            }
        }

        return nil
    }

    private func referencedElement(
        for element: WSDLDefinition.Element,
        in types: WSDLDefinition.Types
    ) -> WSDLDefinition.Element? {
        findSchemaElement(
            named: element.refQName?.localName,
            namespaceURI: element.refQName?.namespaceURI,
            in: types
        )?.element
    }

    private func findComplexType(
        named localName: String?,
        namespaceURI: String?,
        in types: WSDLDefinition.Types
    ) -> WSDLDefinition.ComplexType? {
        guard let localName = localName else {
            return nil
        }

        if let namespaceURI = namespaceURI {
            for schema in types.schemas where schema.targetNamespace == namespaceURI {
                if let complexType = schema.complexTypes.first(where: { $0.name == localName }) {
                    return complexType
                }
            }
        }

        for schema in types.schemas {
            if let complexType = schema.complexTypes.first(where: { $0.name == localName }) {
                return complexType
            }
        }

        return nil
    }

    private func findAttributeGroup(
        named localName: String?,
        namespaceURI: String?,
        in types: WSDLDefinition.Types
    ) -> WSDLDefinition.AttributeGroup? {
        guard let localName = localName else {
            return nil
        }

        if let namespaceURI = namespaceURI {
            for schema in types.schemas where schema.targetNamespace == namespaceURI {
                if let attributeGroup = schema.attributeGroups.first(where: { $0.name == localName }) {
                    return attributeGroup
                }
            }
        }

        for schema in types.schemas {
            if let attributeGroup = schema.attributeGroups.first(where: { $0.name == localName }) {
                return attributeGroup
            }
        }

        return nil
    }

    private func findAttributeDefinition(
        named localName: String?,
        namespaceURI: String?,
        in types: WSDLDefinition.Types
    ) -> WSDLDefinition.Attribute? {
        guard let localName = localName else {
            return nil
        }

        if let namespaceURI = namespaceURI {
            for schema in types.schemas where schema.targetNamespace == namespaceURI {
                if let attributeDefinition = schema.attributeDefinitions.first(where: { $0.name == localName }) {
                    return attributeDefinition
                }
            }
        }

        for schema in types.schemas {
            if let attributeDefinition = schema.attributeDefinitions.first(where: { $0.name == localName }) {
                return attributeDefinition
            }
        }

        return nil
    }

    private func findAttributeGroupKey(
        named localName: String,
        namespaceURI: String?,
        in types: WSDLDefinition.Types
    ) -> AttributeGroupKey? {
        if let namespaceURI = namespaceURI {
            for schema in types.schemas where schema.targetNamespace == namespaceURI {
                if schema.attributeGroups.contains(where: { $0.name == localName }) {
                    return AttributeGroupKey(name: localName, namespaceURI: schema.targetNamespace)
                }
            }
        }

        for schema in types.schemas {
            if schema.attributeGroups.contains(where: { $0.name == localName }) {
                return AttributeGroupKey(name: localName, namespaceURI: schema.targetNamespace)
            }
        }

        return nil
    }

    private func findComplexTypeKey(
        named localName: String,
        namespaceURI: String?,
        in types: WSDLDefinition.Types
    ) -> ComplexTypeKey? {
        if let namespaceURI = namespaceURI {
            for schema in types.schemas where schema.targetNamespace == namespaceURI {
                if schema.complexTypes.contains(where: { $0.name == localName }) {
                    return ComplexTypeKey(name: localName, namespaceURI: schema.targetNamespace)
                }
            }
        }

        for schema in types.schemas {
            if schema.complexTypes.contains(where: { $0.name == localName }) {
                return ComplexTypeKey(name: localName, namespaceURI: schema.targetNamespace)
            }
        }

        return nil
    }

    private func makeSchemaProtocolDescriptors(
        types: WSDLDefinition.Types
    ) throws -> [ComplexTypeKey: SchemaProtocolDescriptor] {
        var hierarchyKeys = Set<ComplexTypeKey>()

        for schema in types.schemas {
            for complexType in schema.complexTypes {
                guard let baseQName = try hierarchyBaseQName(for: complexType, types: types) else {
                    continue
                }

                let complexTypeKey = ComplexTypeKey(name: complexType.name, namespaceURI: schema.targetNamespace)
                hierarchyKeys.insert(complexTypeKey)

                hierarchyKeys.insert(
                    try findRequiredComplexTypeKey(baseQName, types: types, context: complexType.name)
                )
            }
        }

        var descriptors: [ComplexTypeKey: SchemaProtocolDescriptor] = [:]

        for schema in types.schemas {
            for complexType in schema.complexTypes {
                let complexTypeKey = ComplexTypeKey(name: complexType.name, namespaceURI: schema.targetNamespace)
                guard hierarchyKeys.contains(complexTypeKey) else {
                    continue
                }

                let baseTypeKey = try hierarchyBaseQName(for: complexType, types: types).map {
                    try findRequiredComplexTypeKey($0, types: types, context: complexType.name)
                }
                let inheritedProtocolNames: [String]
                if let baseTypeKey = baseTypeKey, hierarchyKeys.contains(baseTypeKey) {
                    inheritedProtocolNames = [generatedProtocolName(forTypeName: sanitizeTypeName(baseTypeKey.name))]
                } else {
                    inheritedProtocolNames = []
                }

                let declaredFieldArtifacts: GeneratedFieldArtifacts
                let declaredAttributes = try resolveDeclaredAttributes(for: complexType, types: types)
                if let simpleContentBaseQName = complexType.simpleContentBaseQName {
                    if baseTypeKey != nil {
                        let fields = declaredAttributes.enumerated().map { index, attribute in
                            attributeField(for: attribute, xmlOrder: index)
                        }
                        declaredFieldArtifacts = GeneratedFieldArtifacts(fields: fields, choiceGroups: [])
                    } else {
                        declaredFieldArtifacts = buildSimpleContentFieldArtifacts(
                            valueTypeQName: simpleContentBaseQName,
                            attributes: declaredAttributes
                        )
                    }
                } else {
                    declaredFieldArtifacts = buildFieldArtifacts(
                        sequence: complexType.sequence,
                        choiceGroups: complexType.choiceGroups,
                        attributes: declaredAttributes,
                        types: types
                    )
                }

                descriptors[complexTypeKey] = SchemaProtocolDescriptor(
                    protocolName: generatedProtocolName(forTypeName: sanitizeTypeName(complexType.name)),
                    inheritedProtocolNames: inheritedProtocolNames,
                    fields: declaredFieldArtifacts.fields
                )
            }
        }

        return descriptors
    }

    private func hierarchyBaseQName(
        for complexType: WSDLDefinition.ComplexType,
        types: WSDLDefinition.Types
    ) throws -> WSDLDefinition.QName? {
        if let baseQName = complexType.baseQName {
            return baseQName
        }

        guard let simpleContentBaseQName = complexType.simpleContentBaseQName else {
            return nil
        }

        guard let baseComplexType = findComplexType(
            named: simpleContentBaseQName.localName,
            namespaceURI: simpleContentBaseQName.namespaceURI,
            in: types
        ) else {
            return nil
        }

        guard baseComplexType.simpleContentBaseQName != nil else {
            throw CodeGenError(
                code: .invalidInput,
                message: "simpleContent type '\(complexType.name)' extends non-simpleContent complexType '\(simpleContentBaseQName.rawValue)'."
            )
        }

        return simpleContentBaseQName
    }

    private func findRequiredComplexTypeKey(
        _ qName: WSDLDefinition.QName,
        types: WSDLDefinition.Types,
        context: String
    ) throws -> ComplexTypeKey {
        guard let baseTypeKey = findComplexTypeKey(
            named: qName.localName,
            namespaceURI: qName.namespaceURI,
            in: types
        ) else {
            throw CodeGenError(
                code: .unresolvedReference,
                message: "complexType '\(context)' extends unknown base type '\(qName.rawValue)'."
            )
        }

        return baseTypeKey
    }

    private func simpleContentValueFieldName(for attributes: [WSDLDefinition.Attribute]) -> String {
        let reservedNames = Set(attributes.map { sanitizePropertyName($0.name) })
        for candidate in ["value", "textValue", "contentValue"] {
            if reservedNames.contains(candidate) == false {
                return candidate
            }
        }
        return "value"
    }
}
