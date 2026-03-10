import Foundation

/// The HTTP transport abstraction used by ``SOAPTransportClientAsync`` to send
/// SOAP request envelopes over the network and receive raw response data.
///
/// Implement this protocol to plug any HTTP client library into the SOAP client stack.
/// The library ships no concrete implementation by design — bring your own transport or
/// use a dedicated companion package (e.g. `swift-soap-urlsession-transport` for URLSession).
///
/// ## Implementing a transport
/// A minimal implementation must:
/// 1. Set `Content-Type: text/xml; charset=utf-8` (SOAP 1.1) or
///    `Content-Type: application/soap+xml; charset=utf-8` (SOAP 1.2).
/// 2. Set the `SOAPAction` HTTP header when `soapAction` is non-nil.
/// 3. Return the raw response body bytes; the codec layer owns XML parsing.
///
/// - Important: Implementations must be `Sendable` and safe to call from concurrent contexts.
///
/// - SeeAlso: ``SOAPClientAttachmentTransport`` for the attachment-aware variant (MTOM/XOP, SwA).
///
/// ## Example: URLSession-based transport
/// ```swift
/// struct URLSessionSOAPTransport: SOAPClientTransport {
///     let session: URLSession = .shared
///
///     func send(_ data: Data, to url: URL, soapAction: String?) async throws -> Data {
///         var request = URLRequest(url: url)
///         request.httpMethod = "POST"
///         request.httpBody = data
///         request.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
///         if let action = soapAction {
///             request.setValue(action, forHTTPHeaderField: "SOAPAction")
///         }
///         let (responseData, _) = try await session.data(for: request)
///         return responseData
///     }
/// }
/// ```
public protocol SOAPClientTransport: Sendable {
    #if swift(>=6.0)
    /// Sends a serialised SOAP envelope to the given endpoint and returns the raw response body.
    ///
    /// - Parameters:
    ///   - requestXMLData: The fully serialised SOAP envelope as UTF-8 XML bytes.
    ///   - endpointURL: The service endpoint to POST to.
    ///   - soapAction: The optional `SOAPAction` header value (SOAP 1.1). Pass `nil` to omit the header.
    /// - Returns: The raw HTTP response body bytes, typically a serialised SOAP envelope.
    /// - Throws: Any transport-level error (network failure, timeout, TLS, etc.).
    func send(_ requestXMLData: Data, to endpointURL: URL, soapAction: String?) async throws(any Error) -> Data
    #else
    /// Sends a serialised SOAP envelope to the given endpoint and returns the raw response body.
    ///
    /// - Parameters:
    ///   - requestXMLData: The fully serialised SOAP envelope as UTF-8 XML bytes.
    ///   - endpointURL: The service endpoint to POST to.
    ///   - soapAction: The optional `SOAPAction` header value (SOAP 1.1). Pass `nil` to omit the header.
    /// - Returns: The raw HTTP response body bytes, typically a serialised SOAP envelope.
    /// - Throws: Any transport-level error (network failure, timeout, TLS, etc.).
    func send(_ requestXMLData: Data, to endpointURL: URL, soapAction: String?) async throws -> Data
    #endif
}
