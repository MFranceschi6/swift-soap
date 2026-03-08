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
