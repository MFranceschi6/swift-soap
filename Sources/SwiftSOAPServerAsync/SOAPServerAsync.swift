import SwiftSOAPCore

#if swift(>=6.0)
public typealias SOAPAsyncOperationHandler<Operation: SOAPOperationContract> = @Sendable (
    Operation.RequestPayload
) async throws(any Error) -> SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>
#else
public typealias SOAPAsyncOperationHandler<Operation: SOAPOperationContract> = @Sendable (
    Operation.RequestPayload
) async throws -> SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>
#endif

public protocol SOAPServerAsync: Sendable {
    #if swift(>=6.0)
    func register<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        handler: @escaping SOAPAsyncOperationHandler<Operation>
    ) async throws(any Error)

    func start() async throws(any Error)
    func stop() async throws(any Error)
    #else
    func register<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        handler: @escaping SOAPAsyncOperationHandler<Operation>
    ) async throws

    func start() async throws
    func stop() async throws
    #endif
}
