import Foundation
import SwiftSOAPCore

extension SOAPTransportClientAsync: SOAPClientAsync {
    #if swift(>=6.0)
    public func invoke<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        request: Operation.RequestPayload,
        endpointURL: URL
    ) async throws(any Error) -> SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload> {
        let requestXMLData = try wireCodec.encodeRequestEnvelope(operation: operation, request: request)
        let responseXMLData = try await transport.send(
            requestXMLData,
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
        let requestXMLData = try wireCodec.encodeRequestEnvelope(operation: operation, request: request)
        let responseXMLData = try await transport.send(
            requestXMLData,
            to: endpointURL,
            soapAction: operation.soapAction?.rawValue
        )
        return try wireCodec.decodeResponseEnvelope(operation: operation, from: responseXMLData)
    }
    #endif
}
