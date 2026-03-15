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

    /// Invokes a one-way SOAP operation without expecting a response payload.
    ///
    /// - Parameters:
    ///   - operation: The operation type describing the request/fault contract.
    ///   - request: The request body payload.
    ///   - endpointURL: The service endpoint URL.
    /// - Throws: `SOAPFaultError` if the service returns a SOAP fault, or any transport/codec error.
    func invokeOneWay<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        request: Operation.RequestPayload,
        endpointURL: URL
    ) async throws(any Error)
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

    /// Invokes a one-way SOAP operation without expecting a response payload.
    ///
    /// - Parameters:
    ///   - operation: The operation type describing the request/fault contract.
    ///   - request: The request body payload.
    ///   - endpointURL: The service endpoint URL.
    /// - Throws: `SOAPFaultError` if the service returns a SOAP fault, or any transport/codec error.
    func invokeOneWay<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        request: Operation.RequestPayload,
        endpointURL: URL
    ) async throws
    #endif
}

extension SOAPClientAsync {
    #if swift(>=6.0)
    public func invokeOneWay<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        request: Operation.RequestPayload,
        endpointURL: URL
    ) async throws(any Error) {
        let response = try await invoke(operation, request: request, endpointURL: endpointURL)
        switch response {
        case .success:
            return
        case .fault(let fault):
            throw SOAPFaultError(fault: fault)
        }
    }

    /// Invokes a SOAP operation and returns the success payload directly, throwing a `SOAPFaultError` on fault.
    public func invoke<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        request: Operation.RequestPayload,
        endpointURL: URL
    ) async throws(any Error) -> Operation.ResponsePayload {
        let response = try await invoke(operation, request: request, endpointURL: endpointURL)
        switch response {
        case .success(let payload):
            return payload
        case .fault(let fault):
            throw SOAPFaultError(fault: fault)
        }
    }
    #else
    public func invokeOneWay<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        request: Operation.RequestPayload,
        endpointURL: URL
    ) async throws {
        let response = try await invoke(operation, request: request, endpointURL: endpointURL)
        switch response {
        case .success:
            return
        case .fault(let fault):
            throw SOAPFaultError(fault: fault)
        }
    }

    /// Invokes a SOAP operation and returns the success payload directly, throwing a `SOAPFaultError` on fault.
    public func invoke<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        request: Operation.RequestPayload,
        endpointURL: URL
    ) async throws -> Operation.ResponsePayload {
        let response = try await invoke(operation, request: request, endpointURL: endpointURL)
        switch response {
        case .success(let payload):
            return payload
        case .fault(let fault):
            throw SOAPFaultError(fault: fault)
        }
    }
    #endif
}
