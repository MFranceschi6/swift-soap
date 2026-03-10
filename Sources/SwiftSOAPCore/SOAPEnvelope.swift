import Foundation

/// A fully typed SOAP envelope that wraps an optional `<Header>` and a `<Body>`.
///
/// `SOAPEnvelope` is the top-level container for a SOAP message. The three generic
/// parameters let the compiler fully resolve payload types at call sites, eliminating
/// runtime type erasure and enabling exhaustive pattern matching on the response.
///
/// In normal usage you do not construct envelopes directly — ``SOAPXMLWireCodec``
/// builds and parses them as part of the encode/decode pipeline. Direct construction
/// is useful for testing or custom server-side handlers.
///
/// ## Creating a request envelope
/// ```swift
/// let envelope = SOAPEnvelope(
///     payload: GetWeatherRequest(cityName: "Rome"),
///     namespace: .soap11
/// )
/// ```
///
/// - SeeAlso: ``SOAPXMLWireCodec``, ``SOAPBody``, ``SOAPHeader``
// swiftlint:disable:next line_length
public struct SOAPEnvelope<BodyPayload: SOAPBodyPayload, HeaderPayload: SOAPHeaderPayload, FaultDetailPayload: SOAPFaultDetailPayload>: Sendable, Codable {
    /// The SOAP 1.1 namespace URI: `http://schemas.xmlsoap.org/soap/envelope/`.
    public static var soap11NamespaceURI: String {
        SOAPEnvelopeNamespace.soap11.uri
    }

    /// The namespace that identifies this envelope as SOAP 1.1 or SOAP 1.2.
    public let namespace: SOAPEnvelopeNamespace
    /// The optional `<Header>` block. `nil` if no header is present.
    public let header: SOAPHeader<HeaderPayload>?
    /// The `<Body>` element, carrying either the payload or a fault.
    public let body: SOAPBody<BodyPayload, FaultDetailPayload>

    /// The namespace URI string derived from ``namespace``.
    public var namespaceURI: String {
        namespace.uri
    }

    /// Creates an envelope from a pre-built ``SOAPBody``.
    ///
    /// - Parameters:
    ///   - namespace: The envelope namespace. Defaults to SOAP 1.1.
    ///   - header: An optional header block.
    ///   - body: The body element.
    public init(
        namespace: SOAPEnvelopeNamespace = .soap11,
        header: SOAPHeader<HeaderPayload>? = nil,
        body: SOAPBody<BodyPayload, FaultDetailPayload>
    ) {
        self.namespace = namespace
        self.header = header
        self.body = body
    }

    #if swift(>=6.0)
    /// Creates an envelope from a pre-built ``SOAPBody``, resolving the namespace from a URI string.
    ///
    /// - Parameters:
    ///   - namespaceURI: The envelope namespace URI. Defaults to the SOAP 1.1 URI.
    ///   - header: An optional header block.
    ///   - body: The body element.
    /// - Throws: ``SOAPCoreError/invalidEnvelope(message:)`` if the URI is unrecognised.
    public init(
        namespaceURI: String = SOAPEnvelope.soap11NamespaceURI,
        header: SOAPHeader<HeaderPayload>? = nil,
        body: SOAPBody<BodyPayload, FaultDetailPayload>
    ) throws(SOAPCoreError) {
        try self.init(
            namespace: SOAPEnvelopeNamespace(uri: namespaceURI),
            header: header,
            body: body
        )
    }
    #else
    /// Creates an envelope from a pre-built ``SOAPBody``, resolving the namespace from a URI string.
    ///
    /// - Parameters:
    ///   - namespaceURI: The envelope namespace URI. Defaults to the SOAP 1.1 URI.
    ///   - header: An optional header block.
    ///   - body: The body element.
    /// - Throws: ``SOAPCoreError/invalidEnvelope(message:)`` if the URI is unrecognised.
    public init(
        namespaceURI: String = SOAPEnvelope.soap11NamespaceURI,
        header: SOAPHeader<HeaderPayload>? = nil,
        body: SOAPBody<BodyPayload, FaultDetailPayload>
    ) throws {
        try self.init(
            namespace: SOAPEnvelopeNamespace(uri: namespaceURI),
            header: header,
            body: body
        )
    }
    #endif

    /// Creates an envelope with a successful body payload.
    ///
    /// - Parameters:
    ///   - payload: The body payload to wrap.
    ///   - namespace: The envelope namespace. Defaults to SOAP 1.1.
    ///   - header: An optional header block.
    public init(
        payload: BodyPayload,
        namespace: SOAPEnvelopeNamespace = .soap11,
        header: SOAPHeader<HeaderPayload>? = nil
    ) {
        self.init(namespace: namespace, header: header, body: .init(payload: payload))
    }

    #if swift(>=6.0)
    /// Creates an envelope with a successful body payload, resolving the namespace from a URI string.
    ///
    /// - Parameters:
    ///   - payload: The body payload to wrap.
    ///   - namespaceURI: The envelope namespace URI.
    ///   - header: An optional header block.
    /// - Throws: ``SOAPCoreError/invalidEnvelope(message:)`` if the URI is unrecognised.
    public init(
        payload: BodyPayload,
        namespaceURI: String,
        header: SOAPHeader<HeaderPayload>? = nil
    ) throws(SOAPCoreError) {
        try self.init(
            namespace: SOAPEnvelopeNamespace(uri: namespaceURI),
            header: header,
            body: .init(payload: payload)
        )
    }
    #else
    /// Creates an envelope with a successful body payload, resolving the namespace from a URI string.
    ///
    /// - Parameters:
    ///   - payload: The body payload to wrap.
    ///   - namespaceURI: The envelope namespace URI.
    ///   - header: An optional header block.
    /// - Throws: ``SOAPCoreError/invalidEnvelope(message:)`` if the URI is unrecognised.
    public init(
        payload: BodyPayload,
        namespaceURI: String,
        header: SOAPHeader<HeaderPayload>? = nil
    ) throws {
        try self.init(
            namespace: SOAPEnvelopeNamespace(uri: namespaceURI),
            header: header,
            body: .init(payload: payload)
        )
    }
    #endif

    /// Creates an envelope with a fault body.
    ///
    /// - Parameters:
    ///   - fault: The SOAP fault to wrap.
    ///   - namespace: The envelope namespace. Defaults to SOAP 1.1.
    ///   - header: An optional header block.
    public init(
        fault: SOAPFault<FaultDetailPayload>,
        namespace: SOAPEnvelopeNamespace = .soap11,
        header: SOAPHeader<HeaderPayload>? = nil
    ) {
        self.init(namespace: namespace, header: header, body: .init(fault: fault))
    }

    #if swift(>=6.0)
    /// Creates an envelope with a fault body, resolving the namespace from a URI string.
    ///
    /// - Parameters:
    ///   - fault: The SOAP fault to wrap.
    ///   - namespaceURI: The envelope namespace URI.
    ///   - header: An optional header block.
    /// - Throws: ``SOAPCoreError/invalidEnvelope(message:)`` if the URI is unrecognised.
    public init(
        fault: SOAPFault<FaultDetailPayload>,
        namespaceURI: String,
        header: SOAPHeader<HeaderPayload>? = nil
    ) throws(SOAPCoreError) {
        try self.init(
            namespace: SOAPEnvelopeNamespace(uri: namespaceURI),
            header: header,
            body: .init(fault: fault)
        )
    }
    #else
    /// Creates an envelope with a fault body, resolving the namespace from a URI string.
    ///
    /// - Parameters:
    ///   - fault: The SOAP fault to wrap.
    ///   - namespaceURI: The envelope namespace URI.
    ///   - header: An optional header block.
    /// - Throws: ``SOAPCoreError/invalidEnvelope(message:)`` if the URI is unrecognised.
    public init(
        fault: SOAPFault<FaultDetailPayload>,
        namespaceURI: String,
        header: SOAPHeader<HeaderPayload>? = nil
    ) throws {
        try self.init(
            namespace: SOAPEnvelopeNamespace(uri: namespaceURI),
            header: header,
            body: .init(fault: fault)
        )
    }
    #endif
}

extension SOAPEnvelope: Equatable where
    BodyPayload: Equatable,
    HeaderPayload: Equatable,
    FaultDetailPayload: Equatable {}
