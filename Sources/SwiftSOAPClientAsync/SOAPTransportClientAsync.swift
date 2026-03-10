import SwiftSOAPCore

/// A concrete async SOAP client that combines a ``SOAPClientTransport`` with a
/// ``SOAPXMLWireCodec`` to execute typed SOAP operations.
///
/// `SOAPTransportClientAsync` is the primary way to invoke SOAP operations from Swift.
/// It implements ``SOAPClientAsync`` and delegates HTTP-level concerns to the injected
/// transport while handling all SOAP encoding and decoding internally via the wire codec.
///
/// ## Basic usage
/// ```swift
/// // Provide your own transport (e.g. from swift-soap-urlsession-transport)
/// let transport = URLSessionSOAPTransport(session: .shared)
/// let client = SOAPTransportClientAsync(transport: transport)
///
/// let response = try await client.invoke(
///     GetWeatherOperation.self,
///     request: GetWeatherRequest(cityName: "Rome"),
///     endpointURL: URL(string: "https://example.com/weather")!
/// )
/// ```
///
/// ## Customising the codec
/// Pass a configured ``SOAPXMLWireCodec`` to control encoding/decoding strategies:
/// ```swift
/// var encoder = XMLEncoder()
/// encoder = XMLEncoder(configuration: .init(dateEncodingStrategy: .iso8601))
/// let codec = SOAPXMLWireCodec(configuration: .init(requestEncoder: encoder))
/// let client = SOAPTransportClientAsync(transport: transport, wireCodec: codec)
/// ```
///
/// - SeeAlso: ``SOAPClientTransport``, ``SOAPXMLWireCodec``, ``SOAPOperationContract``
public struct SOAPTransportClientAsync: Sendable {
    /// The underlying HTTP transport used to send and receive raw SOAP envelopes.
    public let transport: any SOAPClientTransport
    /// The wire codec responsible for encoding requests and decoding responses.
    public let wireCodec: SOAPXMLWireCodec

    /// Creates an async SOAP client with the given transport and codec.
    ///
    /// - Parameters:
    ///   - transport: The HTTP transport implementation. See ``SOAPClientTransport``.
    ///   - wireCodec: The SOAP XML wire codec. Defaults to ``SOAPXMLWireCodec/init(configuration:)``.
    public init(
        transport: any SOAPClientTransport,
        wireCodec: SOAPXMLWireCodec = SOAPXMLWireCodec()
    ) {
        self.transport = transport
        self.wireCodec = wireCodec
    }
}
