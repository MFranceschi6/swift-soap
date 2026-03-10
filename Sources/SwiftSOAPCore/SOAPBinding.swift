/// The SOAP envelope protocol version: SOAP 1.1 or SOAP 1.2.
///
/// The envelope version determines the namespace URI used in `<Envelope>`,
/// the `Content-Type` header value, and the fault element structure.
public enum SOAPBindingEnvelopeVersion: String, Sendable, Codable, CaseIterable {
    /// SOAP 1.1 — namespace `http://schemas.xmlsoap.org/soap/envelope/`.
    case soap11
    /// SOAP 1.2 — namespace `http://www.w3.org/2003/05/soap-envelope`.
    case soap12
}

/// The WSDL binding style: document or RPC.
///
/// - `document`: The message body contains one or more parts that are each defined by
///   a schema type or element. The most common style for WS-I compatible services.
/// - `rpc`: The message body wraps parts inside a wrapper element named after the operation.
public enum SOAPBindingStyle: String, Sendable, Codable, CaseIterable {
    /// Document-style binding. Body parts are raw schema elements (WS-I Basic Profile).
    case document
    /// RPC-style binding. Body parts are wrapped in an operation-named element.
    case rpc
}

/// The WSDL binding body use: literal or encoded.
///
/// - `literal`: Schema types define the exact wire format. WS-I Basic Profile requires literal.
/// - `encoded`: SOAP encoding rules (§5) are applied; largely deprecated in modern services.
public enum SOAPBindingBodyUse: String, Sendable, Codable, CaseIterable {
    /// Literal use — schema directly defines the wire format.
    case literal
    /// Encoded use — SOAP section 5 encoding is applied. Deprecated for most new services.
    case encoded
}

/// The complete set of WSDL binding attributes that govern how SOAP messages are
/// serialised and deserialised by the codec.
///
/// `SOAPBindingMetadata` is supplied by ``SOAPBindingOperationContract`` on each
/// operation type. The codec uses it to select the appropriate ``SOAPBindingCodecStrategy``
/// and to validate that the strategy is compatible with the declared binding.
///
/// Common combinations:
/// - `.document` / `.literal` — WS-I Basic Profile, most interoperable.
/// - `.rpc` / `.literal` — used by some older RPC services.
/// - `.rpc` / `.encoded` — legacy SOAP §5 encoding, largely deprecated.
public struct SOAPBindingMetadata: Sendable, Codable, Equatable {
    /// The SOAP envelope version (1.1 or 1.2).
    public let envelopeVersion: SOAPBindingEnvelopeVersion
    /// The WSDL binding style (document or rpc).
    public let style: SOAPBindingStyle
    /// The WSDL body use (literal or encoded).
    public let bodyUse: SOAPBindingBodyUse

    /// Creates binding metadata from its three constituent attributes.
    ///
    /// - Parameters:
    ///   - envelopeVersion: The SOAP version of the envelope.
    ///   - style: The WSDL binding style.
    ///   - bodyUse: The WSDL body use.
    public init(
        envelopeVersion: SOAPBindingEnvelopeVersion,
        style: SOAPBindingStyle,
        bodyUse: SOAPBindingBodyUse
    ) {
        self.envelopeVersion = envelopeVersion
        self.style = style
        self.bodyUse = bodyUse
    }
}

/// A strategy that validates whether a given ``SOAPBindingMetadata`` combination
/// is supported by a concrete codec implementation.
///
/// Implement this protocol if you are writing a custom codec that only handles
/// a specific binding combination. The default implementations are
/// ``SOAPDocumentLiteralCodecStrategy``, ``SOAPRPCLiteralCodecStrategy``, and
/// ``SOAPRPCEncodedCodecStrategy``.
///
/// - SeeAlso: ``SOAPBindingCodecFactory`` for the factory that selects the right strategy.
public protocol SOAPBindingCodecStrategy: Sendable {
    /// Validates that `metadata` is compatible with this codec strategy.
    ///
    /// - Parameter metadata: The binding metadata to validate.
    /// - Throws: ``SOAPCoreError/unsupportedBinding(message:)`` if the combination is incompatible.
    func validate(metadata: SOAPBindingMetadata) throws
}

/// A ``SOAPBindingCodecStrategy`` for document/literal bindings (WS-I Basic Profile).
///
/// This is the most common binding for modern SOAP services. Validates that
/// the metadata style is `.document` and body use is `.literal`.
public struct SOAPDocumentLiteralCodecStrategy: SOAPBindingCodecStrategy {
    /// Creates a document/literal codec strategy.
    public init() {}

    /// Validates that `metadata` declares document/literal binding.
    ///
    /// - Throws: ``SOAPCoreError/unsupportedBinding(message:)`` for any other combination.
    public func validate(metadata: SOAPBindingMetadata) throws {
        guard metadata.style == .document, metadata.bodyUse == .literal else {
            throw SOAPCoreError.unsupportedBinding(
                message: "Document/literal codec cannot validate metadata '\(metadata.style.rawValue)/\(metadata.bodyUse.rawValue)'."
            )
        }
    }
}

/// A ``SOAPBindingCodecStrategy`` for RPC/literal bindings.
///
/// Validates that the metadata style is `.rpc` and body use is `.literal`.
public struct SOAPRPCLiteralCodecStrategy: SOAPBindingCodecStrategy {
    /// Creates an RPC/literal codec strategy.
    public init() {}

    /// Validates that `metadata` declares RPC/literal binding.
    ///
    /// - Throws: ``SOAPCoreError/unsupportedBinding(message:)`` for any other combination.
    public func validate(metadata: SOAPBindingMetadata) throws {
        guard metadata.style == .rpc, metadata.bodyUse == .literal else {
            throw SOAPCoreError.unsupportedBinding(
                message: "RPC/literal codec cannot validate metadata '\(metadata.style.rawValue)/\(metadata.bodyUse.rawValue)'."
            )
        }
    }
}

/// A ``SOAPBindingCodecStrategy`` for RPC/encoded bindings (SOAP §5 encoding, legacy).
///
/// Validates that the metadata style is `.rpc` and body use is `.encoded`.
/// This combination is largely deprecated in modern web services.
public struct SOAPRPCEncodedCodecStrategy: SOAPBindingCodecStrategy {
    /// Creates an RPC/encoded codec strategy.
    public init() {}

    /// Validates that `metadata` declares RPC/encoded binding.
    ///
    /// - Throws: ``SOAPCoreError/unsupportedBinding(message:)`` for any other combination.
    public func validate(metadata: SOAPBindingMetadata) throws {
        guard metadata.style == .rpc, metadata.bodyUse == .encoded else {
            throw SOAPCoreError.unsupportedBinding(
                message: "RPC/encoded codec cannot validate metadata '\(metadata.style.rawValue)/\(metadata.bodyUse.rawValue)'."
            )
        }
    }
}

/// A factory that creates the appropriate ``SOAPBindingCodecStrategy`` for a given
/// ``SOAPBindingMetadata`` combination.
///
/// Call ``makeCodecStrategy(for:)`` to obtain the canonical strategy for a binding
/// without having to switch on the metadata yourself.
public enum SOAPBindingCodecFactory {
    /// Returns the codec strategy that matches the given binding metadata.
    ///
    /// - Parameter metadata: The binding metadata to match.
    /// - Returns: A ``SOAPBindingCodecStrategy`` for the metadata combination.
    public static func makeCodecStrategy(for metadata: SOAPBindingMetadata) -> any SOAPBindingCodecStrategy {
        switch (metadata.style, metadata.bodyUse) {
        case (.document, .literal):
            return SOAPDocumentLiteralCodecStrategy()
        case (.rpc, .literal):
            return SOAPRPCLiteralCodecStrategy()
        case (.rpc, .encoded):
            return SOAPRPCEncodedCodecStrategy()
        case (.document, .encoded):
            return SOAPRPCEncodedCodecStrategy()
        }
    }
}
