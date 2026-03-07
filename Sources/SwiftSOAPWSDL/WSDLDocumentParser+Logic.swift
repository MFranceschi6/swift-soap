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

                    return WSDLDefinition.BindingOperation(name: operationName, soapAction: soapAction)
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
}
