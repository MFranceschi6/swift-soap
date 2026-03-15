import Foundation
import SwiftSOAPCore
import SwiftSOAPClientAsync
import XCTest

struct ClientErgoTestPayload: Codable, SOAPBodyPayload {
    let value: String
}

struct ClientErgoTestFaultDetail: Codable, SOAPFaultDetailPayload {
    let code: Int
}

struct ClientErgoTestOperation: SOAPOperationContract {
    typealias RequestPayload = ClientErgoTestPayload
    typealias ResponsePayload = ClientErgoTestPayload
    typealias FaultDetailPayload = ClientErgoTestFaultDetail

    static var operationIdentifier: SOAPOperationIdentifier { SOAPOperationIdentifier(rawValue: "TestOp") }
    static var soapAction: SOAPAction? { nil }
    static var bindingMetadata: SOAPBindingMetadata { .init(envelopeVersion: .soap11, style: .document, bodyUse: .literal) }
}

struct ClientErgoOneWayOperation: SOAPOperationContract {
    typealias RequestPayload = ClientErgoTestPayload
    typealias ResponsePayload = SOAPEmptyPayload
    typealias FaultDetailPayload = SOAPEmptyFaultDetailPayload

    static var operationIdentifier: SOAPOperationIdentifier { SOAPOperationIdentifier(rawValue: "OneWayOp") }
    static var soapAction: SOAPAction? { nil }
    static var messageExchangePattern: SOAPMessageExchangePattern { .oneWay }
    static var bindingMetadata: SOAPBindingMetadata { .init(envelopeVersion: .soap11, style: .document, bodyUse: .literal) }
}

final class SOAPClientAsyncErgonomicTests: XCTestCase {
    private final class MockClient: SOAPClientAsync, @unchecked Sendable {
        var response: SOAPOperationResponse<ClientErgoTestPayload, ClientErgoTestFaultDetail>?
        var oneWayResponse: SOAPOperationResponse<SOAPEmptyPayload, SOAPEmptyFaultDetailPayload>?

        func invoke<Operation: SOAPOperationContract>(
            _ operation: Operation.Type,
            request: Operation.RequestPayload,
            endpointURL: URL
        ) async throws -> SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload> {
            if Operation.self == ClientErgoTestOperation.self {
                // swiftlint:disable:next force_cast
                return response as! SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>
            }
            if Operation.self == ClientErgoOneWayOperation.self {
                // swiftlint:disable:next force_cast
                return oneWayResponse as! SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>
            }
            fatalError("Unexpected operation")
        }
    }

    func test_invokeOneWay_onSuccess_doesNotThrow() async throws {
        let client = MockClient()
        client.oneWayResponse = .success(SOAPEmptyPayload())
        
        let url = URL(string: "http://localhost")!
        try await client.invokeOneWay(ClientErgoOneWayOperation.self, request: ClientErgoTestPayload(value: "hi"), endpointURL: url)
    }

    func test_invokeOneWay_onFault_throwsSOAPFaultError() async throws {
        let client = MockClient()
        let fault = try SOAPFault(
            faultCode: .client,
            faultString: "Bad Request",
            detail: SOAPEmptyFaultDetailPayload()
        )
        client.oneWayResponse = .fault(fault)
        
        let url = URL(string: "http://localhost")!
        
        do {
            try await client.invokeOneWay(ClientErgoOneWayOperation.self, request: ClientErgoTestPayload(value: "hi"), endpointURL: url)
            XCTFail("Expected SOAPFaultError to be thrown")
        } catch let error as SOAPFaultError<SOAPEmptyFaultDetailPayload> {
            XCTAssertEqual(error.fault.faultString, "Bad Request")
        } catch {
            XCTFail("Expected SOAPFaultError, got \(error)")
        }
    }
}
