import Foundation
import SwiftSOAPXML
// swiftlint:disable file_length

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

        let namespaceMappings = definitionsNode.namespaceDeclarationsInScope()
        let types = try parseTypes(
            document: document,
            definitionsNode: definitionsNode,
            sourceURL: sourceURL
        )
        let messages = try parseMessages(document: document, namespaceMappings: namespaceMappings)
        let portTypes = try parsePortTypes(document: document, namespaceMappings: namespaceMappings)
        let bindings = try parseBindings(document: document, namespaceMappings: namespaceMappings)
        let services = try parseServices(document: document, namespaceMappings: namespaceMappings)
        try validateDocumentConsistency(
            types: types,
            messages: messages,
            portTypes: portTypes,
            bindings: bindings,
            services: services
        )

        return WSDLDefinition(
            name: definitionsNode.attribute(named: "name"),
            targetNamespace: definitionsNode.attribute(named: "targetNamespace"),
            types: types,
            messages: messages,
            portTypes: portTypes,
            bindings: bindings,
            services: services
        )
    }

    private func parseTypes(
        document: SwiftSOAPXML.XMLDocument,
        definitionsNode: SwiftSOAPXML.XMLNode,
        sourceURL: URL?
    ) throws -> WSDLDefinition.Types {
        let schemaNodes: [SwiftSOAPXML.XMLNode]
        do {
            schemaNodes = try document.xpathNodes(
                "/*[local-name()='definitions']/*[local-name()='types']/*[local-name()='schema']"
            )
        } catch {
            throw WSDLParsingError.other(underlyingError: error, message: "Unable to parse WSDL schema nodes.")
        }

        if schemaNodes.isEmpty {
            return WSDLDefinition.Types(schemas: [])
        }

        var collectedSchemas: [WSDLDefinition.Schema] = []
        var loadedSchemaURLs = Set<String>()
        let fallbackNamespaceMappings = definitionsNode.namespaceDeclarationsInScope()

        for schemaNode in schemaNodes {
            try appendSchemaRecursively(
                schemaNode: schemaNode,
                sourceURL: sourceURL,
                fallbackNamespaceMappings: fallbackNamespaceMappings,
                loadedSchemaURLs: &loadedSchemaURLs,
                schemas: &collectedSchemas
            )
        }

        return WSDLDefinition.Types(schemas: collectedSchemas)
    }

    private func appendSchemaRecursively(
        schemaNode: SwiftSOAPXML.XMLNode,
        sourceURL: URL?,
        fallbackNamespaceMappings: [String: String],
        loadedSchemaURLs: inout Set<String>,
        schemas: inout [WSDLDefinition.Schema]
    ) throws {
        let namespaceMappings = mergedNamespaceMappings(
            schemaNode.namespaceDeclarationsInScope(),
            fallback: fallbackNamespaceMappings
        )

        let parsedSchema = try parseSchema(schemaNode: schemaNode, namespaceMappings: namespaceMappings)
        schemas.append(parsedSchema)

        let schemaReferences = parsedSchema.imports.compactMap { $0.schemaLocation } +
            parsedSchema.includes.map { $0.schemaLocation }

        for schemaLocation in schemaReferences {
            let schemaURL = try resolveLocalSchemaURL(schemaLocation: schemaLocation, sourceURL: sourceURL)
            let schemaURLKey = schemaURL.standardizedFileURL.path
            if loadedSchemaURLs.contains(schemaURLKey) {
                continue
            }
            loadedSchemaURLs.insert(schemaURLKey)

            let schemaData: Data
            do {
                schemaData = try Data(contentsOf: schemaURL)
            } catch {
                throw WSDLParsingError.invalidSchema(
                    name: nil,
                    message: "Unable to load imported schema '\(schemaLocation)' from '\(schemaURL.path)'."
                )
            }

            let importedDocument: SwiftSOAPXML.XMLDocument
            do {
                importedDocument = try SwiftSOAPXML.XMLDocument(data: schemaData, sourceURL: schemaURL, logger: logger)
            } catch {
                throw WSDLParsingError.invalidSchema(
                    name: nil,
                    message: "Unable to parse imported schema '\(schemaLocation)'."
                )
            }

            let importedSchemaNodes = try findSchemaNodes(in: importedDocument)
            for importedSchemaNode in importedSchemaNodes {
                try appendSchemaRecursively(
                    schemaNode: importedSchemaNode,
                    sourceURL: schemaURL,
                    fallbackNamespaceMappings: namespaceMappings,
                    loadedSchemaURLs: &loadedSchemaURLs,
                    schemas: &schemas
                )
            }
        }
    }

    private func findSchemaNodes(in document: SwiftSOAPXML.XMLDocument) throws -> [SwiftSOAPXML.XMLNode] {
        if let rootNode = document.rootElement(), rootNode.name == "schema" {
            return [rootNode]
        }

        do {
            return try document.xpathNodes("//*[local-name()='schema']")
        } catch {
            throw WSDLParsingError.invalidSchema(name: nil, message: "Unable to locate schema root in imported document.")
        }
    }

    private func parseSchema(
        schemaNode: SwiftSOAPXML.XMLNode,
        namespaceMappings: [String: String]
    ) throws -> WSDLDefinition.Schema {
        let targetNamespace = normalized(schemaNode.attribute(named: "targetNamespace"))

        let imports = schemaNode.children()
            .filter { $0.name == "import" }
            .map { importNode in
                WSDLDefinition.SchemaImport(
                    namespace: normalized(importNode.attribute(named: "namespace")),
                    schemaLocation: normalized(importNode.attribute(named: "schemaLocation"))
                )
            }

        let includes = schemaNode.children()
            .filter { $0.name == "include" }
            .compactMap { includeNode -> WSDLDefinition.SchemaInclude? in
                guard let schemaLocation = normalized(includeNode.attribute(named: "schemaLocation")) else {
                    return nil
                }
                return WSDLDefinition.SchemaInclude(schemaLocation: schemaLocation)
            }

        let elements = try schemaNode.children()
            .filter { $0.name == "element" }
            .map { elementNode in
                try parseSchemaElement(elementNode, namespaceMappings: namespaceMappings)
            }

        let complexTypes = try schemaNode.children()
            .filter { $0.name == "complexType" }
            .map { complexTypeNode in
                try parseComplexType(complexTypeNode, namespaceMappings: namespaceMappings)
            }

        let simpleTypes = try schemaNode.children()
            .filter { $0.name == "simpleType" }
            .map { simpleTypeNode in
                try parseSimpleType(simpleTypeNode, namespaceMappings: namespaceMappings)
            }

        return WSDLDefinition.Schema(
            targetNamespace: targetNamespace,
            imports: imports,
            includes: includes,
            elements: elements,
            complexTypes: complexTypes,
            simpleTypes: simpleTypes
        )
    }

    private func parseSchemaElement(
        _ elementNode: SwiftSOAPXML.XMLNode,
        namespaceMappings: [String: String]
    ) throws -> WSDLDefinition.Element {
        let name = normalized(elementNode.attribute(named: "name"))
        let refQName = try resolveQName(
            fromQualifiedName: elementNode.attribute(named: "ref"),
            namespaceMappings: namespaceMappings,
            context: "schema element reference"
        )
        let resolvedName = name ?? refQName?.localName
        guard let resolvedName = resolvedName else {
            throw WSDLParsingError.invalidSchema(name: nil, message: "Schema element is missing both 'name' and 'ref'.")
        }

        let typeQName = try resolveQName(
            fromQualifiedName: elementNode.attribute(named: "type"),
            namespaceMappings: namespaceMappings,
            context: "schema element type"
        )

        let minOccurs = normalized(elementNode.attribute(named: "minOccurs")).flatMap(Int.init)
        let maxOccurs = normalized(elementNode.attribute(named: "maxOccurs"))
        let nillable = normalized(elementNode.attribute(named: "nillable")) == "true" ||
            normalized(elementNode.attribute(named: "nillable")) == "1"

        return WSDLDefinition.Element(
            name: resolvedName,
            typeQName: typeQName,
            refQName: refQName,
            minOccurs: minOccurs,
            maxOccurs: maxOccurs,
            nillable: nillable
        )
    }

    private func parseComplexType(
        _ complexTypeNode: SwiftSOAPXML.XMLNode,
        namespaceMappings: [String: String]
    ) throws -> WSDLDefinition.ComplexType {
        guard let name = normalized(complexTypeNode.attribute(named: "name")) else {
            throw WSDLParsingError.invalidSchema(name: nil, message: "complexType node is missing required 'name'.")
        }

        let sequenceElements = try complexTypeNode.children()
            .filter { $0.name == "sequence" }
            .flatMap { sequenceNode in
                try sequenceNode.children()
                    .filter { $0.name == "element" }
                    .map { elementNode in
                        try parseSchemaElement(elementNode, namespaceMappings: namespaceMappings)
                    }
            }

        let choiceElements = try complexTypeNode.children()
            .filter { $0.name == "choice" }
            .flatMap { choiceNode in
                try choiceNode.children()
                    .filter { $0.name == "element" }
                    .map { elementNode in
                        try parseSchemaElement(elementNode, namespaceMappings: namespaceMappings)
                    }
            }

        let attributes = try complexTypeNode.children()
            .filter { $0.name == "attribute" }
            .map { attributeNode in
                guard let attributeName = normalized(attributeNode.attribute(named: "name")) else {
                    throw WSDLParsingError.invalidSchema(
                        name: name,
                        message: "complexType '\(name)' has an attribute without required 'name'."
                    )
                }
                let typeQName = try resolveQName(
                    fromQualifiedName: attributeNode.attribute(named: "type"),
                    namespaceMappings: namespaceMappings,
                    context: "schema attribute type"
                )

                return WSDLDefinition.Attribute(
                    name: attributeName,
                    typeQName: typeQName,
                    use: normalized(attributeNode.attribute(named: "use"))
                )
            }

        return WSDLDefinition.ComplexType(
            name: name,
            sequence: sequenceElements,
            choice: choiceElements,
            attributes: attributes
        )
    }

    private func parseSimpleType(
        _ simpleTypeNode: SwiftSOAPXML.XMLNode,
        namespaceMappings: [String: String]
    ) throws -> WSDLDefinition.SimpleType {
        guard let name = normalized(simpleTypeNode.attribute(named: "name")) else {
            throw WSDLParsingError.invalidSchema(name: nil, message: "simpleType node is missing required 'name'.")
        }

        let restrictionNode = simpleTypeNode.children().first(where: { $0.name == "restriction" })
        let baseQName = try resolveQName(
            fromQualifiedName: restrictionNode?.attribute(named: "base"),
            namespaceMappings: namespaceMappings,
            context: "simpleType restriction base"
        )
        let enumerationValues = restrictionNode?
            .children()
            .filter { $0.name == "enumeration" }
            .compactMap { enumerationNode in
                normalized(enumerationNode.attribute(named: "value"))
            } ?? []

        let pattern = restrictionNode?
            .children()
            .first(where: { $0.name == "pattern" })?
            .attribute(named: "value")
            .flatMap(normalized)

        return WSDLDefinition.SimpleType(
            name: name,
            baseQName: baseQName,
            enumerationValues: enumerationValues,
            pattern: pattern
        )
    }

    private func parseMessages(
        document: SwiftSOAPXML.XMLDocument,
        namespaceMappings: [String: String]
    ) throws -> [WSDLDefinition.Message] {
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

                    let elementQName = try resolveQName(
                        fromQualifiedName: partNode.attribute(named: "element"),
                        namespaceMappings: namespaceMappings,
                        context: "message part element"
                    )
                    let typeQName = try resolveQName(
                        fromQualifiedName: partNode.attribute(named: "type"),
                        namespaceMappings: namespaceMappings,
                        context: "message part type"
                    )

                    return WSDLDefinition.Part(
                        name: partName,
                        elementName: elementQName?.localName,
                        typeName: typeQName?.localName,
                        elementQName: elementQName,
                        typeQName: typeQName
                    )
                }

            return WSDLDefinition.Message(name: messageName, parts: parts)
        }
    }

    private func parsePortTypes(
        document: SwiftSOAPXML.XMLDocument,
        namespaceMappings: [String: String]
    ) throws -> [WSDLDefinition.PortType] {
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

                    let inputMessageQName = try resolveQName(
                        fromQualifiedName: operationNode
                            .children()
                            .first(where: { $0.name == "input" })?
                            .attribute(named: "message"),
                        namespaceMappings: namespaceMappings,
                        context: "operation input message"
                    )

                    let outputMessageQName = try resolveQName(
                        fromQualifiedName: operationNode
                            .children()
                            .first(where: { $0.name == "output" })?
                            .attribute(named: "message"),
                        namespaceMappings: namespaceMappings,
                        context: "operation output message"
                    )

                    let faults: [WSDLDefinition.Fault] = try operationNode.children()
                        .filter { $0.name == "fault" }
                        .map { faultNode in
                            guard let faultName = faultNode.attribute(named: "name").flatMap(normalized) else {
                                throw WSDLParsingError.invalidOperation(
                                    name: operationName,
                                    message: "Operation '\(operationName)' contains a fault without required 'name'."
                                )
                            }

                            let messageQName = try resolveQName(
                                fromQualifiedName: faultNode.attribute(named: "message"),
                                namespaceMappings: namespaceMappings,
                                context: "fault message"
                            )
                            return WSDLDefinition.Fault(
                                name: faultName,
                                messageName: messageQName?.localName,
                                messageQName: messageQName
                            )
                        }

                    return WSDLDefinition.Operation(
                        name: operationName,
                        inputMessageName: inputMessageQName?.localName,
                        outputMessageName: outputMessageQName?.localName,
                        inputMessageQName: inputMessageQName,
                        outputMessageQName: outputMessageQName,
                        faults: faults
                    )
                }

            return WSDLDefinition.PortType(name: portTypeName, operations: operations)
        }
    }

    private func parseBindings(
        document: SwiftSOAPXML.XMLDocument,
        namespaceMappings: [String: String]
    ) throws -> [WSDLDefinition.Binding] {
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

            let soapBindingNode = bindingNode.children().first(where: { $0.name == "binding" })
            let soapVersion = soapEnvelopeVersion(fromNamespaceURI: soapBindingNode?.namespaceURI)
            let styleKind = soapBindingNode?
                .attribute(named: "style")
                .flatMap(normalized)
                .flatMap(parseSOAPBindingStyle)

            let typeQName = try resolveQName(
                fromQualifiedName: bindingNode.attribute(named: "type"),
                namespaceMappings: namespaceMappings,
                context: "binding type"
            )

            let operations: [WSDLDefinition.BindingOperation] = try bindingNode.children()
                .filter { $0.name == "operation" }
                .map { operationNode in
                    guard let operationName = operationNode.attribute(named: "name").flatMap(normalized) else {
                        throw WSDLParsingError.invalidBinding(
                            name: bindingName,
                            message: "Binding '\(bindingName)' contains an operation without required 'name'."
                        )
                    }

                    let soapOperationNode = operationNode.children().first(where: { $0.name == "operation" })
                    let soapAction = soapOperationNode?.attribute(named: "soapAction").flatMap(normalized)
                    let operationStyleValue = soapOperationNode?.attribute(named: "style").flatMap(normalized)
                    let operationStyle = operationStyleValue.flatMap(parseSOAPBindingStyle)

                    let inputUseValue = operationNode
                        .children()
                        .first(where: { $0.name == "input" })?
                        .children()
                        .first(where: { $0.name == "body" })?
                        .attribute(named: "use")
                        .flatMap(normalized)

                    let outputUseValue = operationNode
                        .children()
                        .first(where: { $0.name == "output" })?
                        .children()
                        .first(where: { $0.name == "body" })?
                        .attribute(named: "use")
                        .flatMap(normalized)

                    return WSDLDefinition.BindingOperation(
                        name: operationName,
                        soapAction: soapAction,
                        style: operationStyleValue,
                        inputUse: inputUseValue,
                        outputUse: outputUseValue,
                        styleKind: operationStyle,
                        inputUseKind: inputUseValue.flatMap(parseSOAPBodyUse),
                        outputUseKind: outputUseValue.flatMap(parseSOAPBodyUse)
                    )
                }

            return WSDLDefinition.Binding(
                name: bindingName,
                typeName: typeQName?.localName,
                style: soapBindingNode?.attribute(named: "style").flatMap(normalized),
                operations: operations,
                typeQName: typeQName,
                soapVersion: soapVersion,
                styleKind: styleKind
            )
        }
    }

    private func parseServices(
        document: SwiftSOAPXML.XMLDocument,
        namespaceMappings: [String: String]
    ) throws -> [WSDLDefinition.Service] {
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

                    let bindingQName = try resolveQName(
                        fromQualifiedName: portNode.attribute(named: "binding"),
                        namespaceMappings: namespaceMappings,
                        context: "service port binding"
                    )

                    return WSDLDefinition.ServicePort(
                        name: portName,
                        bindingName: bindingQName?.localName,
                        address: address,
                        bindingQName: bindingQName
                    )
                }

            return WSDLDefinition.Service(name: serviceName, ports: ports)
        }
    }

    private func validateDocumentConsistency(
        types: WSDLDefinition.Types,
        messages: [WSDLDefinition.Message],
        portTypes: [WSDLDefinition.PortType],
        bindings: [WSDLDefinition.Binding],
        services: [WSDLDefinition.Service]
    ) throws {
        try validateUniqueSchemaTypeNames(types: types)
        try validateUniqueMessageNames(messages)
        try validateUniquePortTypeNames(portTypes)
        try validateUniqueBindingNames(bindings)
        try validateUniqueServiceNames(services)
        try validateTypeReferences(types: types, messages: messages)
        try validatePortTypeOperations(messages: messages, portTypes: portTypes)
        try validateBindings(portTypes: portTypes, bindings: bindings)
        try validateServices(bindings: bindings, services: services)
    }

    private func validateUniqueSchemaTypeNames(types: WSDLDefinition.Types) throws {
        var seenComplexNames = Set<String>()
        var seenSimpleNames = Set<String>()
        var seenElementNames = Set<String>()

        for schema in types.schemas {
            for complexType in schema.complexTypes {
                let fullyQualifiedName = "\(schema.targetNamespace ?? ""):\(complexType.name)"
                if seenComplexNames.contains(fullyQualifiedName) {
                    throw WSDLParsingError.invalidSchema(
                        name: complexType.name,
                        message: "Duplicated complex type '\(complexType.name)'."
                    )
                }
                seenComplexNames.insert(fullyQualifiedName)
            }

            for simpleType in schema.simpleTypes {
                let fullyQualifiedName = "\(schema.targetNamespace ?? ""):\(simpleType.name)"
                if seenSimpleNames.contains(fullyQualifiedName) {
                    throw WSDLParsingError.invalidSchema(
                        name: simpleType.name,
                        message: "Duplicated simple type '\(simpleType.name)'."
                    )
                }
                seenSimpleNames.insert(fullyQualifiedName)
            }

            for element in schema.elements {
                let fullyQualifiedName = "\(schema.targetNamespace ?? ""):\(element.name)"
                if seenElementNames.contains(fullyQualifiedName) {
                    throw WSDLParsingError.invalidSchema(
                        name: element.name,
                        message: "Duplicated schema element '\(element.name)'."
                    )
                }
                seenElementNames.insert(fullyQualifiedName)
            }
        }
    }

    private func validateTypeReferences(types: WSDLDefinition.Types, messages: [WSDLDefinition.Message]) throws {
        var availableTypeNames = Set<String>()
        var availableElementNames = Set<String>()

        for schema in types.schemas {
            for complexType in schema.complexTypes {
                availableTypeNames.insert(complexType.name)
            }
            for simpleType in schema.simpleTypes {
                availableTypeNames.insert(simpleType.name)
            }
            for element in schema.elements {
                availableElementNames.insert(element.name)
            }
        }

        for message in messages {
            for part in message.parts {
                if let typeQName = part.typeQName,
                   !isXMLSchemaBuiltIn(typeQName),
                   !availableTypeNames.contains(typeQName.localName) {
                    throw WSDLParsingError.invalidMessage(
                        name: message.name,
                        message: "Message '\(message.name)' references unknown type '\(typeQName.rawValue)'."
                    )
                }

                if let elementQName = part.elementQName,
                   !availableElementNames.contains(elementQName.localName) {
                    throw WSDLParsingError.invalidMessage(
                        name: message.name,
                        message: "Message '\(message.name)' references unknown element '\(elementQName.rawValue)'."
                    )
                }
            }
        }
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

            if let style = binding.style, parseSOAPBindingStyle(style) == nil {
                throw WSDLParsingError.invalidBinding(
                    name: binding.name,
                    message: "Binding '\(binding.name)' has invalid style '\(style)'."
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

                if let style = operation.style, parseSOAPBindingStyle(style) == nil {
                    throw WSDLParsingError.invalidBinding(
                        name: binding.name,
                        message: "Binding '\(binding.name)' operation '\(operation.name)' has invalid style '\(style)'."
                    )
                }

                if let inputUse = operation.inputUse, parseSOAPBodyUse(inputUse) == nil {
                    throw WSDLParsingError.invalidBinding(
                        name: binding.name,
                        message: "Binding '\(binding.name)' operation '\(operation.name)' has invalid input use '\(inputUse)'."
                    )
                }

                if let outputUse = operation.outputUse, parseSOAPBodyUse(outputUse) == nil {
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

    private func mergedNamespaceMappings(
        _ currentNamespaceMappings: [String: String],
        fallback: [String: String]
    ) -> [String: String] {
        var merged = fallback
        for (key, value) in currentNamespaceMappings {
            merged[key] = value
        }
        return merged
    }

    private func resolveLocalSchemaURL(schemaLocation: String, sourceURL: URL?) throws -> URL {
        if schemaLocation.hasPrefix("http://") || schemaLocation.hasPrefix("https://") {
            throw WSDLParsingError.invalidSchema(
                name: nil,
                message: "Remote schema location '\(schemaLocation)' is not supported in this phase."
            )
        }

        guard let sourceURL = sourceURL else {
            throw WSDLParsingError.invalidSchema(
                name: nil,
                message: "Cannot resolve schema location '\(schemaLocation)' without a source URL."
            )
        }

        let baseDirectoryURL: URL
        if sourceURL.hasDirectoryPath {
            baseDirectoryURL = sourceURL
        } else {
            baseDirectoryURL = sourceURL.deletingLastPathComponent()
        }

        if sourceURL.isFileURL {
            return URL(fileURLWithPath: schemaLocation, relativeTo: baseDirectoryURL).standardizedFileURL
        }

        throw WSDLParsingError.invalidSchema(
            name: nil,
            message: "Only local file URL resolution is supported for schema imports/includes."
        )
    }

    private func resolveQName(
        fromQualifiedName value: String?,
        namespaceMappings: [String: String],
        context: String
    ) throws -> WSDLDefinition.QName? {
        guard let normalizedValue = normalized(value) else {
            return nil
        }

        if let separatorIndex = normalizedValue.firstIndex(of: ":") {
            let prefix = String(normalizedValue[..<separatorIndex])
            let localName = String(normalizedValue[normalizedValue.index(after: separatorIndex)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !localName.isEmpty else {
                throw WSDLParsingError.invalidDocument(
                    message: "Invalid qualified name '\(normalizedValue)' for \(context)."
                )
            }

            guard let namespaceURI = namespaceMappings[prefix] else {
                throw WSDLParsingError.invalidDocument(
                    message: "Unknown namespace prefix '\(prefix)' for \(context) in '\(normalizedValue)'."
                )
            }

            return WSDLDefinition.QName(
                rawValue: normalizedValue,
                prefix: prefix,
                localName: localName,
                namespaceURI: namespaceURI
            )
        }

        return WSDLDefinition.QName(
            rawValue: normalizedValue,
            prefix: nil,
            localName: normalizedValue,
            namespaceURI: namespaceMappings[""]
        )
    }

    private func isXMLSchemaBuiltIn(_ qName: WSDLDefinition.QName) -> Bool {
        if qName.namespaceURI == "http://www.w3.org/2001/XMLSchema" {
            return true
        }

        let builtInLocalNames: Set<String> = [
            "string", "boolean", "decimal", "float", "double", "duration", "dateTime", "time", "date", "gYearMonth",
            "gYear", "gMonthDay", "gDay", "gMonth", "hexBinary", "base64Binary", "anyURI", "QName", "NOTATION",
            "normalizedString", "token", "language", "NMTOKEN", "NMTOKENS", "Name", "NCName", "ID", "IDREF", "IDREFS",
            "ENTITY", "ENTITIES", "integer", "nonPositiveInteger", "negativeInteger", "long", "int", "short", "byte",
            "nonNegativeInteger", "unsignedLong", "unsignedInt", "unsignedShort", "unsignedByte", "positiveInteger"
        ]
        return qName.namespaceURI == nil && builtInLocalNames.contains(qName.localName)
    }

    private func soapEnvelopeVersion(fromNamespaceURI namespaceURI: String?) -> WSDLDefinition.SOAPEnvelopeVersion? {
        guard let namespaceURI = namespaceURI else {
            return nil
        }

        if namespaceURI == "http://schemas.xmlsoap.org/wsdl/soap/" {
            return .soap11
        }
        if namespaceURI == "http://schemas.xmlsoap.org/wsdl/soap12/" {
            return .soap12
        }

        return nil
    }

    private func parseSOAPBindingStyle(_ value: String) -> WSDLDefinition.SOAPBindingStyle? {
        if value == "document" {
            return .document
        }
        if value == "rpc" {
            return .rpc
        }
        return nil
    }

    private func parseSOAPBodyUse(_ value: String) -> WSDLDefinition.SOAPBodyUse? {
        if value == "literal" {
            return .literal
        }
        if value == "encoded" {
            return .encoded
        }
        return nil
    }

    private func normalized(_ value: String?) -> String? {
        guard let value = value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
