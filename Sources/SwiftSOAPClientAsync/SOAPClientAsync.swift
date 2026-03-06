import Foundation
import SwiftSOAPCore

public protocol SOAPClientAsync: Sendable {
    #if swift(>=6.0)
    func invoke<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        request: Operation.RequestPayload,
        endpointURL: URL
    ) async throws(any Error) -> SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>
    #else
    func invoke<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        request: Operation.RequestPayload,
        endpointURL: URL
    ) async throws -> SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>
    #endif
}
