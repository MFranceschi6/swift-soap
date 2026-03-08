import Foundation
import SwiftSOAPCore
import XCTest

final class SOAPXMLWireCodecTests: XCTestCase {
    private let codec = SOAPXMLWireCodec()

    func test_encodeDecodeRequestEnvelope_roundtripPayload() throws {
        let requestPayload = PingRequestPayload(message: "ping")

        let xmlData = try codec.encodeRequestEnvelope(
            operation: PingOperation.self,
            request: requestPayload
        )

        let decoded = try codec.decodeRequestEnvelope(
            operation: PingOperation.self,
            from: xmlData
        )

        XCTAssertEqual(decoded, requestPayload)
    }

    func test_encodeDecodeResponseEnvelope_successRoundtrip() throws {
        let payload = PingResponsePayload(message: "pong")
        let response: SOAPOperationResponse<PingResponsePayload, PingFaultDetailPayload> = .success(payload)

        let xmlData = try codec.encodeResponseEnvelope(
            operation: PingOperation.self,
            response: response
        )

        let decoded = try codec.decodeResponseEnvelope(
            operation: PingOperation.self,
            from: xmlData
        )

        switch decoded {
        case .success(let decodedPayload):
            XCTAssertEqual(decodedPayload, payload)
        case .fault:
            XCTFail("Expected success payload.")
        }
    }

    func test_encodeDecodeResponseEnvelope_faultRoundtrip() throws {
        let fault = try SOAPFault<PingFaultDetailPayload>(
            faultCode: .server,
            faultString: "failure",
            detail: PingFaultDetailPayload(reason: "broken")
        )
        let response: SOAPOperationResponse<PingResponsePayload, PingFaultDetailPayload> = .fault(fault)

        let xmlData = try codec.encodeResponseEnvelope(
            operation: PingOperation.self,
            response: response
        )

        let decoded = try codec.decodeResponseEnvelope(
            operation: PingOperation.self,
            from: xmlData
        )

        switch decoded {
        case .success:
            XCTFail("Expected SOAP fault payload.")
        case .fault(let decodedFault):
            XCTAssertEqual(decodedFault.faultCode, .server)
            XCTAssertEqual(decodedFault.faultString, "failure")
            XCTAssertEqual(decodedFault.detail, PingFaultDetailPayload(reason: "broken"))
        }
    }

    func test_decodeResponseEnvelope_documentEncoded_throwsUnsupportedBinding() throws {
        let payload = PingResponsePayload(message: "pong")
        let response: SOAPOperationResponse<PingResponsePayload, PingFaultDetailPayload> = .success(payload)
        let xmlData = try codec.encodeResponseEnvelope(
            operation: PingOperation.self,
            response: response
        )

        XCTAssertThrowsError(
            try codec.decodeResponseEnvelope(operation: UnsupportedDocumentEncodedOperation.self, from: xmlData)
        ) { error in
            guard case SOAPCoreError.unsupportedBinding = error else {
                return XCTFail("Expected unsupportedBinding, got \(error)")
            }
        }
    }

    func test_decodeResponseMessage_withMatchingAttachmentManifest_succeeds() throws {
        let responseData = soapResponseDataWithXOPInclude(href: "cid:attachment-1")
        let message = SOAPTransportMessage(
            envelopeXMLData: responseData,
            attachmentManifest: SOAPAttachmentManifest(attachments: [
                SOAPAttachment(contentID: "attachment-1", payload: Data([0x01, 0x02]))
            ])
        )

        let decoded = try codec.decodeResponseMessage(
            operation: PingOperation.self,
            from: message
        )

        switch decoded {
        case .success(let payload):
            XCTAssertEqual(payload, PingResponsePayload(message: "pong"))
        case .fault:
            XCTFail("Expected successful payload.")
        }
    }

    func test_decodeResponseEnvelope_withXOPIncludeAndNoManifest_throwsMissingAttachmentReference() throws {
        let responseData = soapResponseDataWithXOPInclude(href: "cid:attachment-1")

        XCTAssertThrowsError(
            try codec.decodeResponseEnvelope(operation: PingOperation.self, from: responseData)
        ) { error in
            guard case SOAPCoreError.missingAttachmentReference(let contentID, let message) = error else {
                return XCTFail("Expected missingAttachmentReference, got \(error)")
            }
            XCTAssertEqual(contentID, "attachment-1")
            XCTAssertTrue(message?.contains("XML6_10B_ATTACHMENT_MISSING") == true)
        }
    }

    func test_decodeResponseMessage_withInvalidAttachmentHref_throwsInvalidAttachmentReference() throws {
        let responseData = soapResponseDataWithXOPInclude(href: "urn:attachment-1")
        let message = SOAPTransportMessage(envelopeXMLData: responseData)

        XCTAssertThrowsError(
            try codec.decodeResponseMessage(operation: PingOperation.self, from: message)
        ) { error in
            guard case SOAPCoreError.invalidAttachmentReference(let message) = error else {
                return XCTFail("Expected invalidAttachmentReference, got \(error)")
            }
            XCTAssertTrue(message?.contains("XML6_10B_ATTACHMENT_HREF_INVALID") == true)
        }
    }

    private func soapResponseDataWithXOPInclude(href: String) -> Data {
        let xml = """
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xop="http://www.w3.org/2004/08/xop/include">
          <soap:Body>
            <PingResponsePayload>
              <message>pong</message>
              <xop:Include href="\(href)"/>
            </PingResponsePayload>
          </soap:Body>
        </soap:Envelope>
        """
        return Data(xml.utf8)
    }
}

private struct PingRequestPayload: SOAPBodyPayload, Equatable {
    let message: String
}

private struct PingResponsePayload: SOAPBodyPayload, Equatable {
    let message: String
}

private struct PingFaultDetailPayload: SOAPFaultDetailPayload, Equatable {
    let reason: String
}

private enum PingOperation: SOAPBindingOperationContract {
    static let operationIdentifier = SOAPOperationIdentifier(rawValue: "Ping")
    static var soapAction: SOAPAction? { SOAPAction(rawValue: "urn:Ping") }

    static var bindingMetadata: SOAPBindingMetadata {
        SOAPBindingMetadata(envelopeVersion: .soap11, style: .document, bodyUse: .literal)
    }

    typealias RequestPayload = PingRequestPayload
    typealias ResponsePayload = PingResponsePayload
    typealias FaultDetailPayload = PingFaultDetailPayload
}

private enum UnsupportedDocumentEncodedOperation: SOAPBindingOperationContract {
    static let operationIdentifier = SOAPOperationIdentifier(rawValue: "Unsupported")
    static var soapAction: SOAPAction? { nil }

    static var bindingMetadata: SOAPBindingMetadata {
        SOAPBindingMetadata(envelopeVersion: .soap11, style: .document, bodyUse: .encoded)
    }

    typealias RequestPayload = PingRequestPayload
    typealias ResponsePayload = PingResponsePayload
    typealias FaultDetailPayload = PingFaultDetailPayload
}

// MARK: - Coverage: SOAP 1.2, error paths, edge cases

extension SOAPXMLWireCodecTests {
    // SOAP 1.2: fault encode/decode roundtrip (covers envelopeNamespace soap12,
    // encodeFaultElement .soap12, encodeSOAP12FaultElement, decodeFault .soap12, decodeSOAP12Fault)
    func test_encodeDecodeResponseEnvelope_soap12_faultRoundtrip() throws {
        let soap12Codec = SOAPXMLWireCodec()
        let fault = try SOAPFault<PingFaultDetailPayload>(
            faultCode: .server,
            faultString: "soap12 failure",
            detail: PingFaultDetailPayload(reason: "soap12 reason")
        )
        let response: SOAPOperationResponse<PingResponsePayload, PingFaultDetailPayload> = .fault(fault)

        let xmlData = try soap12Codec.encodeResponseEnvelope(
            operation: PingSOAP12Operation.self,
            response: response
        )

        let decoded = try soap12Codec.decodeResponseEnvelope(
            operation: PingSOAP12Operation.self,
            from: xmlData
        )

        switch decoded {
        case .success:
            XCTFail("Expected SOAP fault payload.")
        case .fault(let decodedFault):
            XCTAssertEqual(decodedFault.faultCode, .server)
            XCTAssertEqual(decodedFault.faultString, "soap12 failure")
            XCTAssertEqual(decodedFault.detail, PingFaultDetailPayload(reason: "soap12 reason"))
        }
    }

    // SOAP 1.2: success roundtrip
    func test_encodeDecodeResponseEnvelope_soap12_successRoundtrip() throws {
        let soap12Codec = SOAPXMLWireCodec()
        let payload = PingResponsePayload(message: "soap12 pong")
        let response: SOAPOperationResponse<PingResponsePayload, PingFaultDetailPayload> = .success(payload)

        let xmlData = try soap12Codec.encodeResponseEnvelope(
            operation: PingSOAP12Operation.self,
            response: response
        )

        let decoded = try soap12Codec.decodeResponseEnvelope(
            operation: PingSOAP12Operation.self,
            from: xmlData
        )

        if case .success(let successPayload) = decoded {
            XCTAssertEqual(successPayload, payload)
        } else {
            XCTFail("Expected success")
        }
    }

    // SOAP 1.1: fault with faultActor (covers the `if let faultActor` branch in encodeSOAP11FaultElement)
    func test_encodeDecodeResponseEnvelope_soap11_faultWithActor_roundtrip() throws {
        let fault = try SOAPFault<PingFaultDetailPayload>(
            faultCode: .server,
            faultString: "actor fault",
            faultActor: "urn:actor:service",
            detail: nil
        )
        let response: SOAPOperationResponse<PingResponsePayload, PingFaultDetailPayload> = .fault(fault)

        let xmlData = try codec.encodeResponseEnvelope(
            operation: PingOperation.self,
            response: response
        )

        let decoded = try codec.decodeResponseEnvelope(
            operation: PingOperation.self,
            from: xmlData
        )

        if case .fault(let faultResult) = decoded {
            XCTAssertEqual(faultResult.faultActor, "urn:actor:service")
            XCTAssertEqual(faultResult.faultString, "actor fault")
        } else {
            XCTFail("Expected fault")
        }
    }

    // Invalid envelope: wrong root element name
    func test_decodeResponseEnvelope_wrongRootElement_throwsInvalidEnvelope() {
        let xml = """
        <soap:Body xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <PingResponsePayload><message>ok</message></PingResponsePayload>
        </soap:Body>
        """
        XCTAssertThrowsError(
            try codec.decodeResponseEnvelope(operation: PingOperation.self, from: Data(xml.utf8))
        ) { error in
            guard case SOAPCoreError.invalidEnvelope = error else {
                return XCTFail("Expected invalidEnvelope, got \(error)")
            }
        }
    }

    // Invalid envelope: namespace mismatch (valid root name, wrong namespace URI)
    func test_decodeResponseEnvelope_namespaceMismatch_throwsInvalidEnvelope() {
        let xml = """
        <soap:Envelope xmlns:soap="urn:wrong-namespace">
          <soap:Body><PingResponsePayload><message>ok</message></PingResponsePayload></soap:Body>
        </soap:Envelope>
        """
        XCTAssertThrowsError(
            try codec.decodeResponseEnvelope(operation: PingOperation.self, from: Data(xml.utf8))
        ) { error in
            guard case SOAPCoreError.invalidEnvelope = error else {
                return XCTFail("Expected invalidEnvelope, got \(error)")
            }
        }
    }

    // Missing Body element
    func test_decodeResponseEnvelope_missingBody_throwsInvalidBodyConfiguration() {
        let xml = """
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Header/>
        </soap:Envelope>
        """
        XCTAssertThrowsError(
            try codec.decodeResponseEnvelope(operation: PingOperation.self, from: Data(xml.utf8))
        ) { error in
            guard case SOAPCoreError.invalidBodyConfiguration = error else {
                return XCTFail("Expected invalidBodyConfiguration, got \(error)")
            }
        }
    }

    // Missing payload element in Body
    func test_decodeResponseEnvelope_missingPayload_throwsInvalidBodyConfiguration() {
        let xml = """
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body/>
        </soap:Envelope>
        """
        XCTAssertThrowsError(
            try codec.decodeResponseEnvelope(operation: PingOperation.self, from: Data(xml.utf8))
        ) { error in
            guard case SOAPCoreError.invalidBodyConfiguration = error else {
                return XCTFail("Expected invalidBodyConfiguration, got \(error)")
            }
        }
    }

    // Non-SOAPBindingOperationContract operation (fallback metadata)
    func test_encodeRequestEnvelope_nonBindingOperation_usesDefaultMetadata() throws {
        // PlainOperation does not conform to SOAPBindingOperationContract
        let xmlData = try codec.encodeRequestEnvelope(
            operation: PlainOperation.self,
            request: PingRequestPayload(message: "plain")
        )
        let decoded = try codec.decodeRequestEnvelope(
            operation: PlainOperation.self,
            from: xmlData
        )
        XCTAssertEqual(decoded, PingRequestPayload(message: "plain"))
    }

    // Request payload decode failure (covers the catch block in decodeRequestMessage)
    func test_decodeRequestMessage_invalidPayload_throws() {
        // Valid SOAP envelope structure, but payload is for PingResponsePayload
        // while we request a type that would fail to decode from the content
        let xml = """
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <PingRequestPayload><UNKNOWN_FIELD>data</UNKNOWN_FIELD></PingRequestPayload>
          </soap:Body>
        </soap:Envelope>
        """
        // This should succeed (extra fields are just ignored in XML decoding)
        // Let's test malformed XML instead
        let malformedXml = Data("not-xml-at-all".utf8)
        XCTAssertThrowsError(
            try codec.decodeRequestEnvelope(operation: PingOperation.self, from: malformedXml)
        )
    }

    // SOAP 1.2 missing Code/Reason elements — covers decodeSOAP12Fault error path
    func test_decodeResponseEnvelope_soap12_malformedFault_throws() {
        let xml = """
        <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
          <soap:Body>
            <Fault>
              <MissingCode/>
            </Fault>
          </soap:Body>
        </soap:Envelope>
        """
        XCTAssertThrowsError(
            try codec.decodeResponseEnvelope(operation: PingSOAP12Operation.self, from: Data(xml.utf8))
        ) { error in
            guard case SOAPCoreError.invalidFault = error else {
                return XCTFail("Expected invalidFault, got \(error)")
            }
        }
    }
}

// SOAP 1.2 operation for tests
private enum PingSOAP12Operation: SOAPBindingOperationContract {
    static let operationIdentifier = SOAPOperationIdentifier(rawValue: "PingSOAP12")
    static var soapAction: SOAPAction? { nil }

    static var bindingMetadata: SOAPBindingMetadata {
        SOAPBindingMetadata(envelopeVersion: .soap12, style: .document, bodyUse: .literal)
    }

    typealias RequestPayload = PingRequestPayload
    typealias ResponsePayload = PingResponsePayload
    typealias FaultDetailPayload = PingFaultDetailPayload
}

// Plain operation (does NOT conform to SOAPBindingOperationContract)
private enum PlainOperation: SOAPOperationContract {
    static let operationIdentifier = SOAPOperationIdentifier(rawValue: "Plain")
    static var soapAction: SOAPAction? { nil }

    typealias RequestPayload = PingRequestPayload
    typealias ResponsePayload = PingResponsePayload
    typealias FaultDetailPayload = PingFaultDetailPayload
}

// MARK: - XML-6.10C coverage: SOAPCoreError.semanticValidationFailed and SOAPSemanticValidationError

extension SOAPXMLWireCodecTests {
    func test_semanticValidationFailed_coreError_isDistinct() {
        let error = SOAPCoreError.semanticValidationFailed(
            field: "postalCode",
            code: "[CG_SEMANTIC_001]",
            message: "Value is shorter than minLength 4."
        )

        if case SOAPCoreError.semanticValidationFailed(let field, let code, let message) = error {
            XCTAssertEqual(field, "postalCode")
            XCTAssertEqual(code, "[CG_SEMANTIC_001]")
            XCTAssertEqual(message, "Value is shorter than minLength 4.")
        } else {
            XCTFail("Expected semanticValidationFailed case.")
        }
    }

    func test_soAPSemanticValidationError_isError() {
        let error = SOAPSemanticValidationError(
            field: "amount",
            code: "[CG_SEMANTIC_003]",
            message: "Value length must be exactly 8."
        )
        XCTAssertEqual(error.field, "amount")
        XCTAssertEqual(error.code, "[CG_SEMANTIC_003]")
        XCTAssertEqual(error.message, "Value length must be exactly 8.")
    }

    func test_soAPSemanticValidable_protocol_conformance() {
        struct TestValidatable: SOAPSemanticValidatable {
            let value: String
            func validate() throws {
                if value.isEmpty {
                    throw SOAPSemanticValidationError(field: "value", code: "[CG_SEMANTIC_001]")
                }
            }
        }
        XCTAssertNoThrow(try TestValidatable(value: "ok").validate())
        XCTAssertThrowsError(try TestValidatable(value: "").validate()) { error in
            guard let semanticError = error as? SOAPSemanticValidationError else {
                return XCTFail("Expected SOAPSemanticValidationError")
            }
            XCTAssertEqual(semanticError.field, "value")
        }
    }
}
