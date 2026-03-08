import Foundation
import SwiftSOAPXML

extension SOAPXMLWireCodec {
    public func encodeRequestEnvelope<Operation: SOAPOperationContract>(
        operation: Operation.Type,
        request: Operation.RequestPayload
    ) throws -> Data {
        try encodeEnvelopeData(operation: operation, response: nil, request: request)
    }

    public func decodeRequestEnvelope<Operation: SOAPOperationContract>(
        operation: Operation.Type,
        from data: Data
    ) throws -> Operation.RequestPayload {
        let envelope = try parseEnvelope(data: data)
        try validateEnvelopeNamespace(for: envelope, metadata: bindingMetadata(for: operation))
        let bodyElement = try resolveBodyElement(in: envelope)
        let payloadElement = try resolvePayloadElement(in: bodyElement)
        let payloadTree = XMLTreeDocument(root: payloadElement)

        do {
            return try configuration.requestDecoder.decodeTree(Operation.RequestPayload.self, from: payloadTree)
        } catch {
            throw wrapXMLFailure(
                error,
                message: """
                Unable to decode SOAP request payload for operation '\(Operation.operationIdentifier.rawValue)'.
                """
            )
        }
    }

    public func decodeResponseEnvelope<Operation: SOAPOperationContract>(
        operation: Operation.Type,
        from data: Data
    ) throws -> SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload> {
        let metadata = bindingMetadata(for: operation)
        try validateBinding(metadata: metadata)

        let envelope = try parseEnvelope(data: data)
        try validateEnvelopeNamespace(for: envelope, metadata: metadata)

        let bodyElement = try resolveBodyElement(in: envelope)
        let payloadElement = try resolvePayloadElement(in: bodyElement)

        if payloadElement.name.localName == "Fault" {
            let fault: SOAPFault<Operation.FaultDetailPayload> = try decodeFault(
                payloadElement: payloadElement,
                metadata: metadata
            )
            return .fault(fault)
        }

        do {
            let responsePayload = try configuration.responseDecoder.decodeTree(
                Operation.ResponsePayload.self,
                from: XMLTreeDocument(root: payloadElement)
            )
            return .success(responsePayload)
        } catch {
            throw wrapXMLFailure(
                error,
                message: """
                Unable to decode SOAP response payload for operation '\(Operation.operationIdentifier.rawValue)'.
                """
            )
        }
    }

    public func encodeResponseEnvelope<Operation: SOAPOperationContract>(
        operation: Operation.Type,
        response: SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>
    ) throws -> Data {
        try encodeEnvelopeData(operation: operation, response: response, request: nil)
    }
}

private extension SOAPXMLWireCodec {
    func encodeEnvelopeData<Operation: SOAPOperationContract>(
        operation: Operation.Type,
        response: SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>?,
        request: Operation.RequestPayload?
    ) throws -> Data {
        let metadata = bindingMetadata(for: operation)
        try validateBinding(metadata: metadata)

        let envelopeNamespace = envelopeNamespace(for: metadata)
        let envelopeQName = XMLQualifiedName(
            localName: "Envelope",
            namespaceURI: envelopeNamespace.uri,
            prefix: "soap"
        )
        let bodyQName = XMLQualifiedName(
            localName: "Body",
            namespaceURI: envelopeNamespace.uri,
            prefix: "soap"
        )

        let bodyChild: XMLTreeElement
        if let request {
            bodyChild = try encodePayloadElement(request, with: configuration.requestEncoder)
        } else if let response {
            switch response {
            case .success(let payload):
                bodyChild = try encodePayloadElement(payload, with: configuration.responseEncoder)
            case .fault(let fault):
                bodyChild = try encodeFaultElement(fault: fault, metadata: metadata)
            }
        } else {
            throw SOAPCoreError.invalidBodyConfiguration(
                message: "Exactly one payload source is required to encode a SOAP envelope."
            )
        }

        let bodyElement = XMLTreeElement(name: bodyQName, children: [.element(bodyChild)])
        let envelopeElement = XMLTreeElement(
            name: envelopeQName,
            namespaceDeclarations: [XMLNamespaceDeclaration(prefix: "soap", uri: envelopeNamespace.uri)],
            children: [.element(bodyElement)]
        )
        let document = XMLTreeDocument(root: envelopeElement)
        let writer = XMLTreeWriter(configuration: XMLTreeWriter.Configuration(
            prettyPrinted: false,
            attributeOrderingPolicy: .lexicographical,
            namespaceDeclarationOrderingPolicy: .lexicographical,
            deterministicSerializationMode: .stable,
            namespaceValidationMode: .strict
        ))

        do {
            return try writer.writeData(document)
        } catch {
            throw wrapXMLFailure(error, message: "Unable to encode SOAP envelope XML data.")
        }
    }

    func parseEnvelope(data: Data) throws -> XMLTreeDocument {
        let parser = XMLTreeParser(configuration: XMLTreeParser.Configuration(
            whitespaceTextNodePolicy: .dropWhitespaceOnly
        ))

        do {
            return try parser.parse(data: data)
        } catch {
            throw wrapXMLFailure(error, message: "Unable to parse SOAP envelope XML data.")
        }
    }

    func validateBinding(metadata: SOAPBindingMetadata) throws {
        let strategy = SOAPBindingCodecFactory.makeCodecStrategy(for: metadata)
        try strategy.validate(metadata: metadata)
    }

    func bindingMetadata<Operation: SOAPOperationContract>(for operation: Operation.Type) -> SOAPBindingMetadata {
        if let bindingOperation = operation as? any SOAPBindingOperationContract.Type {
            return bindingOperation.bindingMetadata
        }
        return SOAPBindingMetadata(envelopeVersion: .soap11, style: .document, bodyUse: .literal)
    }

    func envelopeNamespace(for metadata: SOAPBindingMetadata) -> SOAPEnvelopeNamespace {
        switch metadata.envelopeVersion {
        case .soap11:
            return .soap11
        case .soap12:
            return .soap12
        }
    }

    func validateEnvelopeNamespace(
        for envelope: XMLTreeDocument,
        metadata: SOAPBindingMetadata
    ) throws {
        let expectedURI = envelopeNamespace(for: metadata).uri
        if envelope.root.name.localName != "Envelope" {
            throw SOAPCoreError.invalidEnvelope(
                message: "Invalid SOAP envelope root element '\(envelope.root.name.localName)'."
            )
        }
        if envelope.root.name.namespaceURI != nil, envelope.root.name.namespaceURI != expectedURI {
            let foundNamespace = envelope.root.name.namespaceURI ?? "<nil>"
            throw SOAPCoreError.invalidEnvelope(
                message: "SOAP envelope namespace mismatch. Expected '\(expectedURI)', found '\(foundNamespace)'."
            )
        }
    }

    func resolveBodyElement(in envelope: XMLTreeDocument) throws -> XMLTreeElement {
        guard let body = firstElementChild(named: "Body", in: envelope.root) else {
            throw SOAPCoreError.invalidBodyConfiguration(message: "SOAP envelope body element is missing.")
        }
        return body
    }

    func resolvePayloadElement(in body: XMLTreeElement) throws -> XMLTreeElement {
        guard let payload = firstElementChild(in: body) else {
            throw SOAPCoreError.invalidBodyConfiguration(message: "SOAP body does not contain a payload element.")
        }
        return payload
    }

    func encodePayloadElement<Payload: Encodable>(
        _ payload: Payload,
        with encoder: XMLEncoder
    ) throws -> XMLTreeElement {
        do {
            return try encoder.encodeTree(payload).root
        } catch {
            throw wrapXMLFailure(error, message: "Unable to encode SOAP payload as XML tree.")
        }
    }

    func decodeFault<FaultDetailPayload: SOAPFaultDetailPayload>(
        payloadElement: XMLTreeElement,
        metadata: SOAPBindingMetadata
    ) throws -> SOAPFault<FaultDetailPayload> {
        switch metadata.envelopeVersion {
        case .soap11:
            return try decodeSOAP11Fault(payloadElement: payloadElement)
        case .soap12:
            return try decodeSOAP12Fault(payloadElement: payloadElement)
        }
    }

    func decodeSOAP11Fault<FaultDetailPayload: SOAPFaultDetailPayload>(
        payloadElement: XMLTreeElement
    ) throws -> SOAPFault<FaultDetailPayload> {
        let faultCodeRaw = try requiredChildText(named: "faultcode", in: payloadElement)
        let faultString = try requiredChildText(named: "faultstring", in: payloadElement)
        let faultActor = optionalChildText(named: "faultactor", in: payloadElement)
        let detailPayload: FaultDetailPayload? = try decodeFaultDetailPayload(
            fromDetailElementNamed: "detail",
            in: payloadElement
        )

        do {
            return try SOAPFault(
                faultCode: SOAPFaultCode(rawValue: faultCodeRaw),
                faultString: faultString,
                faultActor: faultActor,
                detail: detailPayload
            )
        } catch {
            throw SOAPCoreError.invalidFault(
                message: "Unable to decode SOAP 1.1 fault payload: \(error)."
            )
        }
    }

    func decodeSOAP12Fault<FaultDetailPayload: SOAPFaultDetailPayload>(
        payloadElement: XMLTreeElement
    ) throws -> SOAPFault<FaultDetailPayload> {
        guard let codeElement = firstElementChild(named: "Code", in: payloadElement),
              let reasonElement = firstElementChild(named: "Reason", in: payloadElement) else {
            throw SOAPCoreError.invalidFault(message: "SOAP 1.2 fault is missing Code/Reason elements.")
        }

        let faultCodeRaw = try requiredChildText(named: "Value", in: codeElement)
        let faultString = try requiredChildText(named: "Text", in: reasonElement)
        let faultActor = optionalChildText(named: "Role", in: payloadElement)
        let detailPayload: FaultDetailPayload? = try decodeFaultDetailPayload(
            fromDetailElementNamed: "Detail",
            in: payloadElement
        )

        do {
            return try SOAPFault(
                faultCode: SOAPFaultCode(rawValue: faultCodeRaw),
                faultString: faultString,
                faultActor: faultActor,
                detail: detailPayload
            )
        } catch {
            throw SOAPCoreError.invalidFault(
                message: "Unable to decode SOAP 1.2 fault payload: \(error)."
            )
        }
    }

    func encodeFaultElement<FaultDetailPayload: SOAPFaultDetailPayload>(
        fault: SOAPFault<FaultDetailPayload>,
        metadata: SOAPBindingMetadata
    ) throws -> XMLTreeElement {
        switch metadata.envelopeVersion {
        case .soap11:
            return try encodeSOAP11FaultElement(fault: fault)
        case .soap12:
            return try encodeSOAP12FaultElement(fault: fault)
        }
    }

    func encodeSOAP11FaultElement<FaultDetailPayload: SOAPFaultDetailPayload>(
        fault: SOAPFault<FaultDetailPayload>
    ) throws -> XMLTreeElement {
        var children: [XMLTreeNode] = [
            .element(textElement(named: "faultcode", text: fault.faultCode.rawValue)),
            .element(textElement(named: "faultstring", text: fault.faultString))
        ]

        if let faultActor = fault.faultActor {
            children.append(.element(textElement(named: "faultactor", text: faultActor)))
        }

        if let detail = fault.detail {
            let detailPayload = try encodePayloadElement(detail, with: configuration.responseEncoder)
            children.append(.element(XMLTreeElement(
                name: XMLQualifiedName(localName: "detail"),
                children: [.element(detailPayload)]
            )))
        }

        return XMLTreeElement(name: XMLQualifiedName(localName: "Fault"), children: children)
    }

    func encodeSOAP12FaultElement<FaultDetailPayload: SOAPFaultDetailPayload>(
        fault: SOAPFault<FaultDetailPayload>
    ) throws -> XMLTreeElement {
        var children: [XMLTreeNode] = [
            .element(XMLTreeElement(
                name: XMLQualifiedName(localName: "Code"),
                children: [.element(textElement(named: "Value", text: fault.faultCode.rawValue))]
            )),
            .element(XMLTreeElement(
                name: XMLQualifiedName(localName: "Reason"),
                children: [.element(textElement(named: "Text", text: fault.faultString))]
            ))
        ]

        if let faultActor = fault.faultActor {
            children.append(.element(textElement(named: "Role", text: faultActor)))
        }

        if let detail = fault.detail {
            let detailPayload = try encodePayloadElement(detail, with: configuration.responseEncoder)
            children.append(.element(XMLTreeElement(
                name: XMLQualifiedName(localName: "Detail"),
                children: [.element(detailPayload)]
            )))
        }

        return XMLTreeElement(name: XMLQualifiedName(localName: "Fault"), children: children)
    }

    func decodeFaultDetailPayload<FaultDetailPayload: SOAPFaultDetailPayload>(
        fromDetailElementNamed detailElementName: String,
        in faultElement: XMLTreeElement
    ) throws -> FaultDetailPayload? {
        guard let detailElement = firstElementChild(named: detailElementName, in: faultElement),
              let detailPayloadElement = firstElementChild(in: detailElement) else {
            return nil
        }

        do {
            return try configuration.responseDecoder.decodeTree(
                FaultDetailPayload.self,
                from: XMLTreeDocument(root: detailPayloadElement)
            )
        } catch {
            throw wrapXMLFailure(error, message: "Unable to decode SOAP fault detail payload.")
        }
    }

    func textElement(named name: String, text: String) -> XMLTreeElement {
        XMLTreeElement(
            name: XMLQualifiedName(localName: name),
            children: [.text(text)]
        )
    }

    func requiredChildText(named name: String, in element: XMLTreeElement) throws -> String {
        guard let value = optionalChildText(named: name, in: element) else {
            throw SOAPCoreError.invalidFault(message: "Missing required SOAP fault field '\(name)'.")
        }
        return value
    }

    func optionalChildText(named name: String, in element: XMLTreeElement) -> String? {
        guard let child = firstElementChild(named: name, in: element) else {
            return nil
        }
        return firstTextContent(in: child)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func firstElementChild(named localName: String, in element: XMLTreeElement) -> XMLTreeElement? {
        for child in element.children {
            if case .element(let childElement) = child, childElement.name.localName == localName {
                return childElement
            }
        }
        return nil
    }

    func firstElementChild(in element: XMLTreeElement) -> XMLTreeElement? {
        for child in element.children {
            if case .element(let childElement) = child {
                return childElement
            }
        }
        return nil
    }

    func firstTextContent(in element: XMLTreeElement) -> String? {
        for child in element.children {
            switch child {
            case .text(let value), .cdata(let value):
                return value
            case .element:
                continue
            case .comment:
                continue
            }
        }
        return nil
    }

    func wrapXMLFailure(_ error: Error, message: String) -> SOAPCoreError {
        if let soapError = error as? SOAPCoreError {
            return soapError
        }
        return SOAPCoreError.other(underlyingError: error, message: message)
    }
}
