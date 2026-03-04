import Foundation
import SwiftSOAPClientAsync
import SwiftSOAPCore
import XCTest

final class SOAPClientAsyncContractTests: XCTestCase {
    func test_invoke_returnsTypedSuccessResponse() async throws {
        let client = StubSOAPClientAsync()
        let endpointURL = try XCTUnwrap(URL(string: "https://example.com/soap"))
        let request = PingRequestPayload(message: "ping")

        let response = try await client.invoke(
            PingOperationContract.self,
            request: request,
            endpointURL: endpointURL
        )

        switch response {
        case .success(let payload):
            XCTAssertEqual(payload.message, "pong")
        case .fault:
            XCTFail("Expected success response.")
        }

        XCTAssertEqual(PingOperationContract.operationIdentifier.rawValue, "PingOperation")
        XCTAssertEqual(PingOperationContract.soapAction?.rawValue, "urn:PingAction")
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
    static var soapAction: SOAPAction? {
        SOAPAction(rawValue: "urn:PingAction")
    }

    typealias RequestPayload = PingRequestPayload
    typealias ResponsePayload = PingResponsePayload
    typealias FaultDetailPayload = PingFaultDetailPayload
}

private struct StubSOAPClientAsync: SOAPClientAsync {
    func invoke<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        request: Operation.RequestPayload,
        endpointURL: URL
    ) async throws -> SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload> {
        _ = request
        _ = endpointURL

        guard operation == PingOperationContract.self else {
            throw SOAPCoreError.invalidPayload(message: "Unsupported operation.")
        }

        let typedResponse = SOAPOperationResponse<PingResponsePayload, PingFaultDetailPayload>.success(
            PingResponsePayload(message: "pong")
        )

        guard let response = typedResponse as?
            SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>
        else {
            throw SOAPCoreError.invalidPayload(message: "Unable to cast typed async response.")
        }

        return response
    }
}
