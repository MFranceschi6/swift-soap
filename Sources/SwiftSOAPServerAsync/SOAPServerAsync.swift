import SwiftSOAPCore

public typealias SOAPAsyncOperationHandler<Operation: SOAPOperationContract> = @Sendable (
    Operation.RequestPayload
) async throws -> SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>

public protocol SOAPServerAsync: Sendable {
    func register<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        handler: @escaping SOAPAsyncOperationHandler<Operation>
    ) async throws

    func start() async throws
    func stop() async throws
}
