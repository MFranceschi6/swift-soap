import NIOCore
import NIOEmbedded
import SwiftSOAPCore
import SwiftSOAPServerNIO
import XCTest

final class SOAPServerNIOContractTests: XCTestCase {
    func test_registerStartStop_tracksOperationAndLifecycle() throws {
        let eventLoop = EmbeddedEventLoop()
        let server = StubSOAPServerNIO()

        server.register(PingOperationContract.self) { request, loop in
            XCTAssertEqual(request.message, "ping")
            XCTAssertTrue(loop === eventLoop)
            return loop.makeSucceededFuture(.success(PingResponsePayload(message: "pong")))
        }

        try server.start(on: eventLoop).wait()
        XCTAssertTrue(server.isRunning)

        try server.stop(on: eventLoop).wait()
        XCTAssertFalse(server.isRunning)

        XCTAssertEqual(server.operationIdentifiers, [PingOperationContract.operationIdentifier])
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

private final class StubSOAPServerNIO: SOAPServerNIO {
    private(set) var operationIdentifiers: [SOAPOperationIdentifier] = []
    private(set) var isRunning = false

    func register<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        handler: @escaping SOAPNIOOperationHandler<Operation>
    ) {
        _ = handler
        operationIdentifiers.append(operation.operationIdentifier)
    }

    func start(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
        isRunning = true
        return eventLoop.makeSucceededFuture(())
    }

    func stop(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
        isRunning = false
        return eventLoop.makeSucceededFuture(())
    }
}
