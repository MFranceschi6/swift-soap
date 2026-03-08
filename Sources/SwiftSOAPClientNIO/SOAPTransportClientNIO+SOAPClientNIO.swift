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
                let requestXMLData = try wireCodec.encodeRequestEnvelope(operation: operation, request: request)
                let responseXMLData = try await transport.send(
                    requestXMLData,
                    to: endpointURL,
                    soapAction: operation.soapAction?.rawValue
                )
                let response = try wireCodec.decodeResponseEnvelope(operation: operation, from: responseXMLData)
                promise.succeed(response)
            } catch {
                promise.fail(error)
            }
        }

        return promise.futureResult
    }
}
