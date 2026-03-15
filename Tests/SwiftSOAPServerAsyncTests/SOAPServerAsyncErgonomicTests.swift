import Foundation
import SwiftSOAPCore
import SwiftSOAPServerAsync
import XCTest

struct ServerTestPayload: Codable, SOAPBodyPayload {
    let value: String
}

struct ServerTestFaultDetail: Codable, SOAPFaultDetailPayload {
    let code: Int
}

struct ServerTestOperation: SOAPOperationContract {
    typealias RequestPayload = ServerTestPayload
    typealias ResponsePayload = ServerTestPayload
    typealias FaultDetailPayload = ServerTestFaultDetail

    static var operationIdentifier: SOAPOperationIdentifier { SOAPOperationIdentifier(rawValue: "TestOp") }
    static var soapAction: SOAPAction? { nil }
    static var bindingMetadata: SOAPBindingMetadata { .init(envelopeVersion: .soap11, style: .document, bodyUse: .literal) }
}

struct ServerOneWayOperation: SOAPOperationContract {
    typealias RequestPayload = ServerTestPayload
    typealias ResponsePayload = SOAPEmptyPayload
    typealias FaultDetailPayload = SOAPEmptyFaultDetailPayload

    static var operationIdentifier: SOAPOperationIdentifier { SOAPOperationIdentifier(rawValue: "OneWayOp") }
    static var soapAction: SOAPAction? { nil }
    static var messageExchangePattern: SOAPMessageExchangePattern { .oneWay }
    static var bindingMetadata: SOAPBindingMetadata { .init(envelopeVersion: .soap11, style: .document, bodyUse: .literal) }
}

final class SOAPServerAsyncErgonomicTests: XCTestCase {
    private final class MockServer: SOAPServerAsync, @unchecked Sendable {
        var registeredHandlers: [String: Any] = [:]

        func register<Operation: SOAPOperationContract>(
            _ operation: Operation.Type,
            handler: @escaping SOAPAsyncOperationHandler<Operation>
        ) async throws {
            registeredHandlers[Operation.operationIdentifier.rawValue] = handler
        }

        func start() async throws {}
        func stop() async throws {}
    }

    private final class CallCounter: @unchecked Sendable {
        var count = 0
    }

    func test_registerOneWay_wrapsHandlerCorrectly() async throws {
        let server = MockServer()
        let callCounter = CallCounter()
        let expectedRequest = ServerTestPayload(value: "hello")
        
        try await server.registerOneWay(ServerOneWayOperation.self) { request in
            XCTAssertEqual(request.value, "hello")
            callCounter.count += 1
        }
        
        // Retrieve the wrapped handler
        let key = ServerOneWayOperation.operationIdentifier.rawValue
        let handler = try XCTUnwrap(
            server.registeredHandlers[key] as? SOAPAsyncOperationHandler<ServerOneWayOperation>
        )

        // Invoke it
        _ = try await handler(expectedRequest)
        
        XCTAssertEqual(callCounter.count, 1)
    }

    func test_registerOneWay_mapsSOAPFaultErrorToFaultResponse() async throws {
        let server = MockServer()
        let expectedFault = try SOAPFault(
            faultCode: .server,
            faultString: "Server Error",
            detail: SOAPEmptyFaultDetailPayload()
        )
        
        try await server.registerOneWay(ServerOneWayOperation.self) { _ in
            throw SOAPFaultError<SOAPEmptyFaultDetailPayload>(fault: expectedFault)
        }
        
        let key2 = ServerOneWayOperation.operationIdentifier.rawValue
        let handler = try XCTUnwrap(
            server.registeredHandlers[key2] as? SOAPAsyncOperationHandler<ServerOneWayOperation>
        )

        let response = try await handler(ServerTestPayload(value: "trigger fault"))
        
        switch response {
        case .success:
            XCTFail("Expected .fault response")
        case .fault(let fault):
            XCTAssertEqual(fault.faultString, "Server Error")
        }
    }
}
