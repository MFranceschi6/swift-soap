import SwiftSOAPXML

/// The central codec that encodes SOAP request envelopes and decodes SOAP response envelopes.
///
/// `SOAPXMLWireCodec` bridges typed Swift operation payloads to and from XML bytes.
/// It is owned and used by ``SOAPTransportClientAsync``; you rarely need to interact
/// with it directly unless you are writing a custom client or server handler.
///
/// ## Encode/decode pipeline
/// ```
/// encode: operation + request → SOAPEnvelope → XMLEncoder → Data
/// decode: Data → XMLDecoder → SOAPEnvelope → body resolver → SOAPOperationResponse
/// ```
///
/// ## Customising the codec
/// Pass a ``Configuration`` to tune the underlying ``XMLEncoder`` and ``XMLDecoder``
/// instances — for example to set custom date strategies or namespace mappings:
/// ```swift
/// var encoderConfig = XMLEncoder()
/// encoderConfig.dateEncodingStrategy = .iso8601
/// let codec = SOAPXMLWireCodec(
///     configuration: .init(requestEncoder: encoderConfig)
/// )
/// ```
///
/// - SeeAlso: ``SOAPXMLWireCodec+Logic`` for the encode/decode implementation details.
public struct SOAPXMLWireCodec: Sendable {
    /// Configuration that holds the ``XMLEncoder`` and ``XMLDecoder`` instances used
    /// for request encoding and response decoding.
    ///
    /// Request and response encoders/decoders are kept separate so that each direction
    /// can be tuned independently (e.g. different date strategies for incoming vs outgoing).
    public struct Configuration: Sendable {
        /// The encoder used to serialise outgoing request payloads.
        public let requestEncoder: XMLEncoder
        /// The encoder used to serialise outgoing response payloads (server-side).
        public let responseEncoder: XMLEncoder
        /// The decoder used to deserialise incoming request payloads (server-side).
        public let requestDecoder: XMLDecoder
        /// The decoder used to deserialise incoming response payloads.
        public let responseDecoder: XMLDecoder

        /// Creates a codec configuration.
        ///
        /// - Parameters:
        ///   - requestEncoder: Encoder for outgoing requests. Defaults to `XMLEncoder()`.
        ///   - responseEncoder: Encoder for outgoing responses. Defaults to `XMLEncoder()`.
        ///   - requestDecoder: Decoder for incoming requests. Defaults to `XMLDecoder()`.
        ///   - responseDecoder: Decoder for incoming responses. Defaults to `XMLDecoder()`.
        public init(
            requestEncoder: XMLEncoder = XMLEncoder(),
            responseEncoder: XMLEncoder = XMLEncoder(),
            requestDecoder: XMLDecoder = XMLDecoder(),
            responseDecoder: XMLDecoder = XMLDecoder()
        ) {
            self.requestEncoder = requestEncoder
            self.responseEncoder = responseEncoder
            self.requestDecoder = requestDecoder
            self.responseDecoder = responseDecoder
        }
    }

    /// The encoder/decoder configuration for this codec.
    public let configuration: Configuration

    /// Creates a wire codec with the given configuration.
    ///
    /// - Parameter configuration: Encoder/decoder configuration. Defaults to ``Configuration/init()``.
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }
}
