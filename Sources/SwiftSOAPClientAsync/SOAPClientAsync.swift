import Foundation
import SwiftSOAPCore

/// An async SOAP client capable of invoking typed SOAP operations.
///
/// Conform to `SOAPClientAsync` to implement a custom SOAP client (e.g. a mock for testing).
/// The concrete implementation provided by the library is ``SOAPTransportClientAsync``.
///
/// - SeeAlso: ``SOAPTransportClientAsync``, ``SOAPOperationContract``, ``SOAPOperationResponse``
public protocol SOAPClientAsync: Sendable {
    #if swift(>=6.0)
    /// Invokes a SOAP operation and returns the typed response.
    ///
    /// - Parameters:
    ///   - operation: The operation type describing the request/response/fault contract.
    ///   - request: The request body payload.
    ///   - endpointURL: The service endpoint URL.
    /// - Returns: A ``SOAPOperationResponse`` containing either the success payload or a SOAP fault.
    /// - Throws: Any transport or codec error encountered during the invocation.
    func invoke<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        request: Operation.RequestPayload,
        endpointURL: URL
    ) async throws(any Error) -> SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>
    #else
    /// Invokes a SOAP operation and returns the typed response.
    ///
    /// - Parameters:
    ///   - operation: The operation type describing the request/response/fault contract.
    ///   - request: The request body payload.
    ///   - endpointURL: The service endpoint URL.
    /// - Returns: A ``SOAPOperationResponse`` containing either the success payload or a SOAP fault.
    /// - Throws: Any transport or codec error encountered during the invocation.
    func invoke<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        request: Operation.RequestPayload,
        endpointURL: URL
    ) async throws -> SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>
    #endif
}
