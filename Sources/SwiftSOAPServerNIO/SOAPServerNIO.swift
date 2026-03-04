import NIOCore
import SwiftSOAPCore

public typealias SOAPNIOOperationHandler<Operation: SOAPOperationContract> = (
    Operation.RequestPayload,
    EventLoop
) -> EventLoopFuture<SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>>

public protocol SOAPServerNIO {
    func register<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        handler: @escaping SOAPNIOOperationHandler<Operation>
    )

    func start(on eventLoop: EventLoop) -> EventLoopFuture<Void>
    func stop(on eventLoop: EventLoop) -> EventLoopFuture<Void>
}
