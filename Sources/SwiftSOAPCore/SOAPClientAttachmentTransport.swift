import Foundation

/// An extended transport protocol for SOAP operations that carry MIME multipart
/// attachments (MTOM/XOP or SwA — SOAP with Attachments).
///
/// Implement `SOAPClientAttachmentTransport` instead of ``SOAPClientTransport`` when
/// your transport layer needs to receive the full ``SOAPTransportMessage`` including
/// the attachment manifest (binary parts, content IDs, MIME headers), rather than
/// only the raw XML envelope bytes.
///
/// ``SOAPTransportClientAsync`` automatically detects conformance to this protocol at
/// runtime: if the transport conforms, it routes through the attachment-aware `send`
/// overload; otherwise it falls back to the plain XML `send`.
///
/// - SeeAlso: ``SOAPClientTransport``, ``SOAPTransportMessage``, ``SOAPAttachmentManifest``
public protocol SOAPClientAttachmentTransport: SOAPClientTransport {
    #if swift(>=6.0)
    /// Sends a full SOAP transport message (envelope + attachments) and returns the response.
    ///
    /// - Parameters:
    ///   - request: The complete transport message including the XML envelope and any attachments.
    ///   - endpointURL: The service endpoint to POST to.
    ///   - soapAction: The optional `SOAPAction` header value. Pass `nil` to omit the header.
    /// - Returns: The response transport message, including any response attachments.
    /// - Throws: Any transport-level error.
    func send(
        _ request: SOAPTransportMessage,
        to endpointURL: URL,
        soapAction: String?
    ) async throws(any Error) -> SOAPTransportMessage
    #else
    /// Sends a full SOAP transport message (envelope + attachments) and returns the response.
    ///
    /// - Parameters:
    ///   - request: The complete transport message including the XML envelope and any attachments.
    ///   - endpointURL: The service endpoint to POST to.
    ///   - soapAction: The optional `SOAPAction` header value. Pass `nil` to omit the header.
    /// - Returns: The response transport message, including any response attachments.
    /// - Throws: Any transport-level error.
    func send(
        _ request: SOAPTransportMessage,
        to endpointURL: URL,
        soapAction: String?
    ) async throws -> SOAPTransportMessage
    #endif
}
