import Foundation
import SwiftSOAPCore

extension SOAPTransportClientAsync: SOAPClientAsync {
    #if swift(>=6.0)
    /// Invokes a SOAP operation by encoding the request, sending it via the transport,
    /// and decoding the response.
    ///
    /// If the transport also conforms to ``SOAPClientAttachmentTransport``, the
    /// full ``SOAPTransportMessage`` (including any attachment manifest) is passed through
    /// instead of just the raw XML bytes.
    ///
    /// - Parameters:
    ///   - operation: The operation type describing the request/response/fault contract.
    ///   - request: The request body payload.
    ///   - endpointURL: The service endpoint URL.
    /// - Returns: A ``SOAPOperationResponse`` containing either the success payload or a SOAP fault.
    /// - Throws: Any transport or codec error.
    public func invoke<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        request: Operation.RequestPayload,
        endpointURL: URL
    ) async throws(any Error) -> SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload> {
        let requestMessage = try wireCodec.encodeRequestMessage(operation: operation, request: request)
        if let attachmentTransport = transport as? any SOAPClientAttachmentTransport {
            let responseMessage = try await attachmentTransport.send(
                requestMessage,
                to: endpointURL,
                soapAction: operation.soapAction?.rawValue
            )
            return try wireCodec.decodeResponseMessage(operation: operation, from: responseMessage)
        }

        let responseXMLData = try await transport.send(
            requestMessage.envelopeXMLData,
            to: endpointURL,
            soapAction: operation.soapAction?.rawValue
        )
        return try wireCodec.decodeResponseEnvelope(operation: operation, from: responseXMLData)
    }
    #else
    /// Invokes a SOAP operation by encoding the request, sending it via the transport,
    /// and decoding the response.
    ///
    /// - Parameters:
    ///   - operation: The operation type describing the request/response/fault contract.
    ///   - request: The request body payload.
    ///   - endpointURL: The service endpoint URL.
    /// - Returns: A ``SOAPOperationResponse`` containing either the success payload or a SOAP fault.
    /// - Throws: Any transport or codec error.
    public func invoke<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        request: Operation.RequestPayload,
        endpointURL: URL
    ) async throws -> SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload> {
        let requestMessage = try wireCodec.encodeRequestMessage(operation: operation, request: request)
        if let attachmentTransport = transport as? any SOAPClientAttachmentTransport {
            let responseMessage = try await attachmentTransport.send(
                requestMessage,
                to: endpointURL,
                soapAction: operation.soapAction?.rawValue
            )
            return try wireCodec.decodeResponseMessage(operation: operation, from: responseMessage)
        }

        let responseXMLData = try await transport.send(
            requestMessage.envelopeXMLData,
            to: endpointURL,
            soapAction: operation.soapAction?.rawValue
        )
        return try wireCodec.decodeResponseEnvelope(operation: operation, from: responseXMLData)
    }
    #endif
}
