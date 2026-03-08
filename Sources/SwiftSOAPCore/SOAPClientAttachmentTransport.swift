import Foundation

public protocol SOAPClientAttachmentTransport: SOAPClientTransport {
    #if swift(>=6.0)
    func send(
        _ request: SOAPTransportMessage,
        to endpointURL: URL,
        soapAction: String?
    ) async throws(any Error) -> SOAPTransportMessage
    #else
    func send(
        _ request: SOAPTransportMessage,
        to endpointURL: URL,
        soapAction: String?
    ) async throws -> SOAPTransportMessage
    #endif
}
