import Foundation
import SwiftSOAPXML

extension WSDLDocumentParser {
    func parseDocument(data: Data, sourceURL: URL?) throws -> WSDLDefinition {
        logger.debug("Parsing WSDL document", metadata: [
            "byteCount": "\(data.count)"
        ])

        let document: SwiftSOAPXML.XMLDocument
        do {
            if let sourceURL = sourceURL {
                document = try SwiftSOAPXML.XMLDocument(data: data, sourceURL: sourceURL, logger: logger)
            } else {
                document = try SwiftSOAPXML.XMLDocument(data: data, logger: logger)
            }
        } catch {
            throw WSDLParsingError.other(underlyingError: error, message: "Unable to parse XML document.")
        }

        guard let definitionsNode = try document.xpathFirstNode("/*[local-name()='definitions']") else {
            throw WSDLParsingError.invalidDocument(message: "Missing wsdl:definitions root node.")
        }

        let messages = try parseMessages(document: document)
        let portTypes = try parsePortTypes(document: document)
        let bindings = try parseBindings(document: document)
        let services = try parseServices(document: document)
        try validateDocumentConsistency(
            messages: messages,
            portTypes: portTypes,
            bindings: bindings,
            services: services
        )

        return WSDLDefinition(
            name: definitionsNode.attribute(named: "name"),
            targetNamespace: definitionsNode.attribute(named: "targetNamespace"),
            messages: messages,
            portTypes: portTypes,
            bindings: bindings,
            services: services
        )
    }

    private func parseMessages(document: SwiftSOAPXML.XMLDocument) throws -> [WSDLDefinition.Message] {
        let nodes: [SwiftSOAPXML.XMLNode]
        do {
            nodes = try document.xpathNodes("/*[local-name()='definitions']/*[local-name()='message']")
        } catch {
            throw WSDLParsingError.other(underlyingError: error, message: "Unable to parse WSDL messages.")
        }

        return try nodes.map { node in
            guard let messageName = node.attribute(named: "name").flatMap(normalized) else {
                throw WSDLParsingError.invalidMessage(name: nil, message: "Message node is missing required 'name'.")
            }

            let parts: [WSDLDefinition.Part] = try node.children()
                .filter { $0.name == "part" }
                .map { partNode in
                    guard let partName = partNode.attribute(named: "name").flatMap(normalized) else {
                        throw WSDLParsingError.invalidMessage(
                            name: messageName,
                            message: "Message '\(messageName)' contains a part without required 'name'."
                        )
                    }

                    return WSDLDefinition.Part(
                        name: partName,
                        elementName: localName(fromQualifiedName: partNode.attribute(named: "element")),
                        typeName: localName(fromQualifiedName: partNode.attribute(named: "type"))
                    )
                }

            return WSDLDefinition.Message(name: messageName, parts: parts)
        }
    }

    private func parsePortTypes(document: SwiftSOAPXML.XMLDocument) throws -> [WSDLDefinition.PortType] {
        let nodes: [SwiftSOAPXML.XMLNode]
        do {
            nodes = try document.xpathNodes("/*[local-name()='definitions']/*[local-name()='portType']")
        } catch {
            throw WSDLParsingError.other(underlyingError: error, message: "Unable to parse WSDL port types.")
        }

        return try nodes.map { portTypeNode in
            guard let portTypeName = portTypeNode.attribute(named: "name").flatMap(normalized) else {
                throw WSDLParsingError.invalidPortType(name: nil, message: "Port type node is missing required 'name'.")
            }

            let operations: [WSDLDefinition.Operation] = try portTypeNode.children()
                .filter { $0.name == "operation" }
                .map { operationNode in
                    guard let operationName = operationNode.attribute(named: "name").flatMap(normalized) else {
                        throw WSDLParsingError.invalidOperation(
                            name: nil,
                            message: "Port type '\(portTypeName)' contains an operation without required 'name'."
                        )
                    }

                    let inputMessageName = localName(fromQualifiedName: operationNode
                        .children()
                        .first(where: { $0.name == "input" })?
                        .attribute(named: "message"))

                    let outputMessageName = localName(fromQualifiedName: operationNode
                        .children()
                        .first(where: { $0.name == "output" })?
                        .attribute(named: "message"))

                    let faults: [WSDLDefinition.Fault] = try operationNode.children()
                        .filter { $0.name == "fault" }
                        .map { faultNode in
                            guard let faultName = faultNode.attribute(named: "name").flatMap(normalized) else {
                                throw WSDLParsingError.invalidOperation(
                                    name: operationName,
                                    message: "Operation '\(operationName)' contains a fault without required 'name'."
                                )
                            }

                            return WSDLDefinition.Fault(
                                name: faultName,
                                messageName: localName(fromQualifiedName: faultNode.attribute(named: "message"))
                            )
                        }

                    return WSDLDefinition.Operation(
                        name: operationName,
                        inputMessageName: inputMessageName,
                        outputMessageName: outputMessageName,
                        faults: faults
                    )
                }

            return WSDLDefinition.PortType(name: portTypeName, operations: operations)
        }
    }

    private func parseBindings(document: SwiftSOAPXML.XMLDocument) throws -> [WSDLDefinition.Binding] {
        let nodes: [SwiftSOAPXML.XMLNode]
        do {
            nodes = try document.xpathNodes("/*[local-name()='definitions']/*[local-name()='binding']")
        } catch {
            throw WSDLParsingError.other(underlyingError: error, message: "Unable to parse WSDL bindings.")
        }

        return try nodes.map { bindingNode in
            guard let bindingName = bindingNode.attribute(named: "name").flatMap(normalized) else {
                throw WSDLParsingError.invalidBinding(name: nil, message: "Binding node is missing required 'name'.")
            }

            let style = bindingNode
                .children()
                .first(where: { $0.name == "binding" })?
                .attribute(named: "style")
                .flatMap(normalized)

            let operations: [WSDLDefinition.BindingOperation] = try bindingNode.children()
                .filter { $0.name == "operation" }
                .map { operationNode in
                    guard let operationName = operationNode.attribute(named: "name").flatMap(normalized) else {
                        throw WSDLParsingError.invalidBinding(
                            name: bindingName,
                            message: "Binding '\(bindingName)' contains an operation without required 'name'."
                        )
                    }

                    let soapAction = operationNode
                        .children()
                        .first(where: { $0.name == "operation" })?
                        .attribute(named: "soapAction")
                        .flatMap(normalized)

                    let operationStyle = operationNode
                        .children()
                        .first(where: { $0.name == "operation" })?
                        .attribute(named: "style")
                        .flatMap(normalized)

                    let inputUse = operationNode
                        .children()
                        .first(where: { $0.name == "input" })?
                        .children()
                        .first(where: { $0.name == "body" })?
                        .attribute(named: "use")
                        .flatMap(normalized)

                    let outputUse = operationNode
                        .children()
                        .first(where: { $0.name == "output" })?
                        .children()
                        .first(where: { $0.name == "body" })?
                        .attribute(named: "use")
                        .flatMap(normalized)

                    return WSDLDefinition.BindingOperation(
                        name: operationName,
                        soapAction: soapAction,
                        style: operationStyle,
                        inputUse: inputUse,
                        outputUse: outputUse
                    )
                }

            return WSDLDefinition.Binding(
                name: bindingName,
                typeName: localName(fromQualifiedName: bindingNode.attribute(named: "type")),
                style: style,
                operations: operations
            )
        }
    }

    private func parseServices(document: SwiftSOAPXML.XMLDocument) throws -> [WSDLDefinition.Service] {
        let nodes: [SwiftSOAPXML.XMLNode]
        do {
            nodes = try document.xpathNodes("/*[local-name()='definitions']/*[local-name()='service']")
        } catch {
            throw WSDLParsingError.other(underlyingError: error, message: "Unable to parse WSDL services.")
        }

        return try nodes.map { serviceNode in
            guard let serviceName = serviceNode.attribute(named: "name").flatMap(normalized) else {
                throw WSDLParsingError.invalidService(name: nil, message: "Service node is missing required 'name'.")
            }

            let ports: [WSDLDefinition.ServicePort] = try serviceNode.children()
                .filter { $0.name == "port" }
                .map { portNode in
                    guard let portName = portNode.attribute(named: "name").flatMap(normalized) else {
                        throw WSDLParsingError.invalidServicePort(
                            name: nil,
                            message: "Service '\(serviceName)' contains a port without required 'name'."
                        )
                    }

                    let address = portNode
                        .children()
                        .first(where: { $0.name == "address" })?
                        .attribute(named: "location")
                        .flatMap(normalized)

                    return WSDLDefinition.ServicePort(
                        name: portName,
                        bindingName: localName(fromQualifiedName: portNode.attribute(named: "binding")),
                        address: address
                    )
                }

            return WSDLDefinition.Service(name: serviceName, ports: ports)
        }
    }

    private func validateDocumentConsistency(
        messages: [WSDLDefinition.Message],
        portTypes: [WSDLDefinition.PortType],
        bindings: [WSDLDefinition.Binding],
        services: [WSDLDefinition.Service]
    ) throws {
        try validateUniqueMessageNames(messages)
        try validateUniquePortTypeNames(portTypes)
        try validateUniqueBindingNames(bindings)
        try validateUniqueServiceNames(services)
        try validatePortTypeOperations(messages: messages, portTypes: portTypes)
        try validateBindings(portTypes: portTypes, bindings: bindings)
        try validateServices(bindings: bindings, services: services)
    }

    private func validateUniqueMessageNames(_ messages: [WSDLDefinition.Message]) throws {
        var seenNames = Set<String>()
        for message in messages {
            if seenNames.contains(message.name) {
                throw WSDLParsingError.invalidMessage(
                    name: message.name,
                    message: "Duplicated message name '\(message.name)'."
                )
            }
            seenNames.insert(message.name)
        }
    }

    private func validateUniquePortTypeNames(_ portTypes: [WSDLDefinition.PortType]) throws {
        var seenNames = Set<String>()
        for portType in portTypes {
            if seenNames.contains(portType.name) {
                throw WSDLParsingError.invalidPortType(
                    name: portType.name,
                    message: "Duplicated port type name '\(portType.name)'."
                )
            }
            seenNames.insert(portType.name)
        }
    }

    private func validateUniqueBindingNames(_ bindings: [WSDLDefinition.Binding]) throws {
        var seenNames = Set<String>()
        for binding in bindings {
            if seenNames.contains(binding.name) {
                throw WSDLParsingError.invalidBinding(
                    name: binding.name,
                    message: "Duplicated binding name '\(binding.name)'."
                )
            }
            seenNames.insert(binding.name)
        }
    }

    private func validateUniqueServiceNames(_ services: [WSDLDefinition.Service]) throws {
        var seenNames = Set<String>()
        for service in services {
            if seenNames.contains(service.name) {
                throw WSDLParsingError.invalidService(
                    name: service.name,
                    message: "Duplicated service name '\(service.name)'."
                )
            }
            seenNames.insert(service.name)

            var seenPortNames = Set<String>()
            for port in service.ports {
                if seenPortNames.contains(port.name) {
                    throw WSDLParsingError.invalidServicePort(
                        name: port.name,
                        message: "Service '\(service.name)' contains duplicated port name '\(port.name)'."
                    )
                }
                seenPortNames.insert(port.name)
            }
        }
    }

    private func validatePortTypeOperations(
        messages: [WSDLDefinition.Message],
        portTypes: [WSDLDefinition.PortType]
    ) throws {
        let messageNames = Set(messages.map { $0.name })

        for portType in portTypes {
            var seenOperationNames = Set<String>()
            for operation in portType.operations {
                if seenOperationNames.contains(operation.name) {
                    throw WSDLParsingError.invalidOperation(
                        name: operation.name,
                        message: "Port type '\(portType.name)' contains duplicated operation '\(operation.name)'."
                    )
                }
                seenOperationNames.insert(operation.name)

                if let inputMessageName = operation.inputMessageName, !messageNames.contains(inputMessageName) {
                    throw WSDLParsingError.invalidOperation(
                        name: operation.name,
                        message: "Operation '\(operation.name)' references unknown input message '\(inputMessageName)'."
                    )
                }

                if let outputMessageName = operation.outputMessageName, !messageNames.contains(outputMessageName) {
                    throw WSDLParsingError.invalidOperation(
                        name: operation.name,
                        message: "Operation '\(operation.name)' references unknown output message '\(outputMessageName)'."
                    )
                }

                for fault in operation.faults {
                    if let messageName = fault.messageName, !messageNames.contains(messageName) {
                        throw WSDLParsingError.invalidOperation(
                            name: operation.name,
                            message: "Operation '\(operation.name)' fault '\(fault.name)' references unknown message '\(messageName)'."
                        )
                    }
                }
            }
        }
    }

    private func validateBindings(
        portTypes: [WSDLDefinition.PortType],
        bindings: [WSDLDefinition.Binding]
    ) throws {
        var portTypeOperationsByName: [String: Set<String>] = [:]
        for portType in portTypes {
            let operationNames = Set(portType.operations.map { $0.name })
            portTypeOperationsByName[portType.name] = operationNames
        }

        for binding in bindings {
            guard let typeName = binding.typeName else {
                throw WSDLParsingError.invalidBinding(
                    name: binding.name,
                    message: "Binding '\(binding.name)' is missing required 'type' reference."
                )
            }

            guard let portTypeOperations = portTypeOperationsByName[typeName] else {
                throw WSDLParsingError.invalidBinding(
                    name: binding.name,
                    message: "Binding '\(binding.name)' references unknown port type '\(typeName)'."
                )
            }

            var seenOperationNames = Set<String>()
            for operation in binding.operations {
                if seenOperationNames.contains(operation.name) {
                    throw WSDLParsingError.invalidBinding(
                        name: binding.name,
                        message: "Binding '\(binding.name)' contains duplicated operation '\(operation.name)'."
                    )
                }
                seenOperationNames.insert(operation.name)

                if !portTypeOperations.contains(operation.name) {
                    throw WSDLParsingError.invalidBinding(
                        name: binding.name,
                        message: "Binding '\(binding.name)' operation '\(operation.name)' is not declared in port type '\(typeName)'."
                    )
                }

                if let inputUse = operation.inputUse, !isValidSoapBodyUse(inputUse) {
                    throw WSDLParsingError.invalidBinding(
                        name: binding.name,
                        message: "Binding '\(binding.name)' operation '\(operation.name)' has invalid input use '\(inputUse)'."
                    )
                }

                if let outputUse = operation.outputUse, !isValidSoapBodyUse(outputUse) {
                    throw WSDLParsingError.invalidBinding(
                        name: binding.name,
                        message: "Binding '\(binding.name)' operation '\(operation.name)' has invalid output use '\(outputUse)'."
                    )
                }
            }
        }
    }

    private func validateServices(
        bindings: [WSDLDefinition.Binding],
        services: [WSDLDefinition.Service]
    ) throws {
        let bindingNames = Set(bindings.map { $0.name })

        for service in services {
            for port in service.ports {
                guard let bindingName = port.bindingName else {
                    throw WSDLParsingError.invalidServicePort(
                        name: port.name,
                        message: "Service '\(service.name)' port '\(port.name)' is missing required 'binding' reference."
                    )
                }

                if !bindingNames.contains(bindingName) {
                    throw WSDLParsingError.invalidServicePort(
                        name: port.name,
                        message: "Service '\(service.name)' port '\(port.name)' references unknown binding '\(bindingName)'."
                    )
                }
            }
        }
    }

    private func localName(fromQualifiedName value: String?) -> String? {
        guard let value = normalized(value) else {
            return nil
        }

        if let separator = value.firstIndex(of: ":") {
            let localName = value[value.index(after: separator)...]
            let normalizedLocalName = String(localName).trimmingCharacters(in: .whitespacesAndNewlines)
            return normalizedLocalName.isEmpty ? nil : normalizedLocalName
        }

        return value
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private func isValidSoapBodyUse(_ value: String) -> Bool {
        value == "literal" || value == "encoded"
    }
}
