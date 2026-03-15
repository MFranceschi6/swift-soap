import NIOCore
import SwiftSOAPCore

public typealias SOAPNIOOperationHandler<Operation: SOAPOperationContract> = (
    Operation.RequestPayload,
    EventLoop
) -> EventLoopFuture<SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>>

public typealias SOAPNIOOneWayOperationHandler<Operation: SOAPOperationContract> = (
    Operation.RequestPayload,
    EventLoop
) -> EventLoopFuture<Void>

public protocol SOAPServerNIO {
    func register<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        handler: @escaping SOAPNIOOperationHandler<Operation>
    )

    func registerOneWay<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        handler: @escaping SOAPNIOOneWayOperationHandler<Operation>
    )

    func start(on eventLoop: EventLoop) -> EventLoopFuture<Void>
    func stop(on eventLoop: EventLoop) -> EventLoopFuture<Void>
}

extension SOAPServerNIO {
    public func registerOneWay<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        handler: @escaping SOAPNIOOneWayOperationHandler<Operation>
    ) {
        register(operation) { request, eventLoop in
            handler(request, eventLoop).flatMapErrorThrowing { error in
                if let faultError = error as? SOAPFaultError<Operation.FaultDetailPayload> {
                    throw faultError // Or handle mapping strictly if needed. Actually NIO handlers return EventLoopFuture<SOAPOperationResponse<...>>
                }
                throw error
            }.map { _ in
                fatalError("registerOneWay default implementation requires framework adapter support, or the codec to drop the success value.")
            }
        }
    }
}
