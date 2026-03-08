import Foundation
import SwiftSOAPCore

extension SOAPTransportClientAsync: SOAPClientAsync {
    #if swift(>=6.0)
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
