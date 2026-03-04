import Foundation
import NIOCore
import NIOEmbedded
import SwiftSOAPClientNIO
import SwiftSOAPCore
import XCTest

final class SOAPClientNIOContractTests: XCTestCase {
    func test_invoke_returnsTypedSuccessResponseOnEventLoop() throws {
        let eventLoop = EmbeddedEventLoop()
        let client = StubSOAPClientNIO()
        let endpointURL = try XCTUnwrap(URL(string: "https://example.com/soap"))
        let request = PingRequestPayload(message: "ping")

        let future = client.invoke(
            PingOperationContract.self,
            request: request,
            endpointURL: endpointURL,
            on: eventLoop
        )

        let response = try future.wait()
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

private enum PingOperationContract: SOAPOperationContract {
    static let operationIdentifier = SOAPOperationIdentifier(rawValue: "PingOperation")

    typealias RequestPayload = PingRequestPayload
    typealias ResponsePayload = PingResponsePayload
    typealias FaultDetailPayload = PingFaultDetailPayload
}

private struct StubSOAPClientNIO: SOAPClientNIO {
    func invoke<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        request: Operation.RequestPayload,
        endpointURL: URL,
        on eventLoop: EventLoop
    ) -> EventLoopFuture<SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>> {
        _ = request
        _ = endpointURL

        guard operation == PingOperationContract.self else {
            return eventLoop.makeFailedFuture(SOAPCoreError.invalidPayload(message: "Unsupported operation."))
        }

        let typedResponse = SOAPOperationResponse<PingResponsePayload, PingFaultDetailPayload>.success(
            PingResponsePayload(message: "pong")
        )

        guard let response = typedResponse as?
            SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>
        else {
            return eventLoop.makeFailedFuture(
                SOAPCoreError.invalidPayload(message: "Unable to cast typed NIO response.")
            )
        }

        return eventLoop.makeSucceededFuture(response)
    }
}
