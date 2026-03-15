import Foundation
import NIOCore
import SwiftSOAPCore

public protocol SOAPClientNIO {
    func invoke<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        request: Operation.RequestPayload,
        endpointURL: URL,
        on eventLoop: EventLoop
    ) -> EventLoopFuture<SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>>

    func invokeOneWay<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        request: Operation.RequestPayload,
        endpointURL: URL,
        on eventLoop: EventLoop
    ) -> EventLoopFuture<Void>
}

extension SOAPClientNIO {
    public func invokeOneWay<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        request: Operation.RequestPayload,
        endpointURL: URL,
        on eventLoop: EventLoop
    ) -> EventLoopFuture<Void> {
        invoke(operation, request: request, endpointURL: endpointURL, on: eventLoop).flatMapThrowing { response in
            switch response {
            case .success:
                return ()
            case .fault(let fault):
                throw SOAPFaultError(fault: fault)
            }
        }
    }

    /// Invokes a SOAP operation and returns the success payload directly via a future, throwing a `SOAPFaultError` on fault.
    public func invoke<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        request: Operation.RequestPayload,
        endpointURL: URL,
        on eventLoop: EventLoop
    ) -> EventLoopFuture<Operation.ResponsePayload> {
        invoke(operation, request: request, endpointURL: endpointURL, on: eventLoop).flatMapThrowing { response in
            switch response {
            case .success(let payload):
                return payload
            case .fault(let fault):
                throw SOAPFaultError(fault: fault)
            }
        }
    }
}
