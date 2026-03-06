import Foundation

// swiftlint:disable:next line_length
public struct SOAPEnvelope<BodyPayload: SOAPBodyPayload, HeaderPayload: SOAPHeaderPayload, FaultDetailPayload: SOAPFaultDetailPayload>: Sendable, Codable {
    public static var soap11NamespaceURI: String {
        SOAPEnvelopeNamespace.soap11.uri
    }

    public let namespace: SOAPEnvelopeNamespace
    public let header: SOAPHeader<HeaderPayload>?
    public let body: SOAPBody<BodyPayload, FaultDetailPayload>

    public var namespaceURI: String {
        namespace.uri
    }

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

    public init(
        payload: BodyPayload,
        namespace: SOAPEnvelopeNamespace = .soap11,
        header: SOAPHeader<HeaderPayload>? = nil
    ) {
        self.init(namespace: namespace, header: header, body: .init(payload: payload))
    }

    #if swift(>=6.0)
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

    public init(
        fault: SOAPFault<FaultDetailPayload>,
        namespace: SOAPEnvelopeNamespace = .soap11,
        header: SOAPHeader<HeaderPayload>? = nil
    ) {
        self.init(namespace: namespace, header: header, body: .init(fault: fault))
    }

    #if swift(>=6.0)
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
