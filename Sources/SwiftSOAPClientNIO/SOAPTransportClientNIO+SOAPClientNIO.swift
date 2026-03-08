import Foundation
import NIOCore
import SwiftSOAPCore

extension SOAPTransportClientNIO: SOAPClientNIO {
    public func invoke<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        request: Operation.RequestPayload,
        endpointURL: URL,
        on eventLoop: EventLoop
    ) -> EventLoopFuture<SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>> {
        let promise = eventLoop.makePromise(
            of: SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>.self
        )

        Task {
            do {
                let requestMessage = try wireCodec.encodeRequestMessage(operation: operation, request: request)
                let response: SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>

                if let attachmentTransport = transport as? any SOAPClientAttachmentTransport {
                    let responseMessage = try await attachmentTransport.send(
                        requestMessage,
                        to: endpointURL,
                        soapAction: operation.soapAction?.rawValue
                    )
                    response = try wireCodec.decodeResponseMessage(operation: operation, from: responseMessage)
                } else {
                    let responseXMLData = try await transport.send(
                        requestMessage.envelopeXMLData,
                        to: endpointURL,
                        soapAction: operation.soapAction?.rawValue
                    )
                    response = try wireCodec.decodeResponseEnvelope(operation: operation, from: responseXMLData)
                }
                promise.succeed(response)
            } catch {
                promise.fail(error)
            }
        }

        return promise.futureResult
    }
}
