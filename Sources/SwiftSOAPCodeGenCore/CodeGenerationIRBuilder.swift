import Foundation
import SwiftSOAPWSDL

public struct CodeGenerationIRBuilder {
    public init() {}

    public func build(from definition: WSDLDefinition, configuration: CodeGenConfiguration) throws -> SOAPCodeGenerationIR {
        var generatedTypes: [GeneratedTypeIR] = []
        var generatedTypeNames = Set<String>()

        let messagesByName = Dictionary(uniqueKeysWithValues: definition.messages.map { ($0.name, $0) })
        let portTypesByName = Dictionary(uniqueKeysWithValues: definition.portTypes.map { ($0.name, $0) })
        let bindingsByName = Dictionary(uniqueKeysWithValues: definition.bindings.map { ($0.name, $0) })

        let messageTypes = try buildMessagePayloadTypes(messages: definition.messages, generatedTypeNames: &generatedTypeNames)
        generatedTypes.append(contentsOf: messageTypes)

        let schemaTypes = try buildSchemaTypes(types: definition.types, generatedTypeNames: &generatedTypeNames)
        generatedTypes.append(contentsOf: schemaTypes)

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
            generatedTypes: generatedTypes,
            services: services
        )
    }

    private func buildMessagePayloadTypes(
        messages: [WSDLDefinition.Message],
        generatedTypeNames: inout Set<String>
    ) throws -> [GeneratedTypeIR] {
        return try messages.map { message in
            let payloadTypeName = sanitizeTypeName("\(message.name)Payload")
            try ensureUniqueSymbol(payloadTypeName, generatedTypeNames: &generatedTypeNames)

            let fields = message.parts.map { part in
                GeneratedTypeFieldIR(
                    name: sanitizePropertyName(part.name),
                    swiftTypeName: swiftTypeName(forQNameLocalName: part.typeName),
                    isOptional: true
                )
            }

            return GeneratedTypeIR(swiftTypeName: payloadTypeName, kind: .bodyPayload, fields: fields)
        }
    }

    private func buildSchemaTypes(
        types: WSDLDefinition.Types,
        generatedTypeNames: inout Set<String>
    ) throws -> [GeneratedTypeIR] {
        var generatedTypes: [GeneratedTypeIR] = []

        for schema in types.schemas {
            for complexType in schema.complexTypes {
                let schemaSwiftTypeName = sanitizeTypeName(complexType.name)
                try ensureUniqueSymbol(schemaSwiftTypeName, generatedTypeNames: &generatedTypeNames)

                let sequenceFields = complexType.sequence.map { element in
                    GeneratedTypeFieldIR(
                        name: sanitizePropertyName(element.name),
                        swiftTypeName: swiftTypeName(forQNameLocalName: element.typeQName?.localName),
                        isOptional: element.minOccurs == nil || element.minOccurs == 0
                    )
                }

                let choiceFields = complexType.choice.map { element in
                    GeneratedTypeFieldIR(
                        name: sanitizePropertyName(element.name),
                        swiftTypeName: swiftTypeName(forQNameLocalName: element.typeQName?.localName),
                        isOptional: true
                    )
                }

                let attributeFields = complexType.attributes.map { attribute in
                    GeneratedTypeFieldIR(
                        name: sanitizePropertyName(attribute.name),
                        swiftTypeName: swiftTypeName(forQNameLocalName: attribute.typeQName?.localName),
                        isOptional: attribute.use != "required"
                    )
                }

                generatedTypes.append(
                    GeneratedTypeIR(
                        swiftTypeName: schemaSwiftTypeName,
                        kind: .schemaModel,
                        fields: sequenceFields + choiceFields + attributeFields
                    )
                )
            }

            for simpleType in schema.simpleTypes {
                let schemaSwiftTypeName = sanitizeTypeName(simpleType.name)
                try ensureUniqueSymbol(schemaSwiftTypeName, generatedTypeNames: &generatedTypeNames)

                let fieldTypeName = swiftTypeName(forQNameLocalName: simpleType.baseQName?.localName)
                let fields = [GeneratedTypeFieldIR(name: "rawValue", swiftTypeName: fieldTypeName, isOptional: false)]

                generatedTypes.append(
                    GeneratedTypeIR(
                        swiftTypeName: schemaSwiftTypeName,
                        kind: .schemaModel,
                        fields: fields
                    )
                )
            }
        }

        return generatedTypes
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

        let operations = try portType.operations.map { operation in
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
                            GeneratedTypeFieldIR(
                                name: sanitizePropertyName(part.name),
                                swiftTypeName: swiftTypeName(forQNameLocalName: part.typeName),
                                isOptional: true
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
            bindingMetadata: resolvedBindingMetadata
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

    private func ensureUniqueSymbol(_ symbol: String, generatedTypeNames: inout Set<String>) throws {
        if generatedTypeNames.contains(symbol) {
            throw CodeGenError(code: .duplicateSymbol, message: "Duplicated generated symbol '\(symbol)'.")
        }
        generatedTypeNames.insert(symbol)
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

        var result = tokens[0].lowercased()
        if tokens.count > 1 {
            for token in tokens.dropFirst() {
                result += token.prefix(1).uppercased() + token.dropFirst().lowercased()
            }
        }

        if let firstCharacter = result.first, firstCharacter.isNumber {
            return "value\(result)"
        }

        let reserved: Set<String> = [
            "class", "struct", "enum", "protocol", "func", "let", "var", "extension", "default"
        ]

        if reserved.contains(result) {
            return "`\(result)`"
        }

        return result
    }
}
