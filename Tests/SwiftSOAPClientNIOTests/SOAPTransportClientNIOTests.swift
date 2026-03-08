import Foundation
import NIOCore
import NIOPosix
import SwiftSOAPClientNIO
import SwiftSOAPCore
import XCTest

final class SOAPTransportClientNIOTests: XCTestCase {
    func test_invoke_serializesToXMLAndDecodesResponseOnEventLoop() async throws {
        let transport = StubClientTransport()
        let client = SOAPTransportClientNIO(transport: transport)
        let endpointURL = try XCTUnwrap(URL(string: "https://example.com/soap"))
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        addTeardownBlock {
            try await eventLoopGroup.shutdownGracefully()
        }
        let eventLoop = eventLoopGroup.next()

        let response = try await client.invoke(
            PingOperation.self,
            request: PingRequestPayload(message: "ping"),
            endpointURL: endpointURL,
            on: eventLoop
        ).get()

        let receivedRequestData = await transport.lastRequestData
        let receivedSOAPAction = await transport.lastSOAPAction
        XCTAssertNotNil(receivedRequestData)
        XCTAssertEqual(receivedSOAPAction, "urn:Ping")

        switch response {
        case .success(let payload):
            XCTAssertEqual(payload.message, "pong")
        case .fault:
            XCTFail("Expected success response.")
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

private actor StubClientTransport: SOAPClientTransport {
    let codec = SOAPXMLWireCodec()
    private(set) var lastRequestData: Data?
    private(set) var lastSOAPAction: String?

    func send(_ requestXMLData: Data, to endpointURL: URL, soapAction: String?) async throws -> Data {
        _ = endpointURL
        lastRequestData = requestXMLData
        lastSOAPAction = soapAction

        let request = try codec.decodeRequestEnvelope(operation: PingOperation.self, from: requestXMLData)
        let response: SOAPOperationResponse<PingResponsePayload, PingFaultDetailPayload> = .success(
            PingResponsePayload(message: request.message == "ping" ? "pong" : "unexpected")
        )
        return try codec.encodeResponseEnvelope(operation: PingOperation.self, response: response)
    }
}
