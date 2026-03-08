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
