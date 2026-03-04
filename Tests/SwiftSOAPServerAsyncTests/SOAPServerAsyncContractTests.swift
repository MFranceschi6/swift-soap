import SwiftSOAPCore
import SwiftSOAPServerAsync
import XCTest

final class SOAPServerAsyncContractTests: XCTestCase {
    func test_registerStartStop_tracksOperationAndLifecycle() async throws {
        let server = StubSOAPServerAsync()

        try await server.register(PingOperationContract.self) { request in
            XCTAssertEqual(request.message, "ping")
            return .success(PingResponsePayload(message: "pong"))
        }

        try await server.start()
        let runningAfterStart = await server.isRunning()
        XCTAssertTrue(runningAfterStart)

        try await server.stop()
        let runningAfterStop = await server.isRunning()
        XCTAssertFalse(runningAfterStop)

        let identifiers = await server.registeredOperationIdentifiers()
        XCTAssertEqual(identifiers, [PingOperationContract.operationIdentifier])
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

private actor StubSOAPServerAsync: SOAPServerAsync {
    private var operationIdentifiers: [SOAPOperationIdentifier] = []
    private var running = false

    func register<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        handler: @escaping SOAPAsyncOperationHandler<Operation>
    ) async throws {
        _ = handler
        operationIdentifiers.append(operation.operationIdentifier)
    }

    func start() async throws {
        running = true
    }

    func stop() async throws {
        running = false
    }

    func isRunning() -> Bool {
        running
    }

    func registeredOperationIdentifiers() -> [SOAPOperationIdentifier] {
        operationIdentifiers
    }
}
