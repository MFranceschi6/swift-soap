/// A marker protocol for types that model the contents of a SOAP `<Header>` element.
///
/// Conform any `Codable` + `Sendable` type to `SOAPHeaderPayload` to carry
/// custom header blocks (e.g. WS-Security tokens, routing headers) alongside
/// the operation body.
///
/// - SeeAlso: ``SOAPEmptyHeaderPayload`` for operations that require no header.
/// - SeeAlso: ``SOAPEnvelope`` which holds the optional header alongside the body.
public protocol SOAPHeaderPayload: Codable, Sendable {}

/// A concrete ``SOAPHeaderPayload`` that represents an absent `<Header>` element.
///
/// Use `SOAPEmptyHeaderPayload` as the `HeaderPayload` type parameter on
/// ``SOAPEnvelope`` when no header block is needed.
public struct SOAPEmptyHeaderPayload: SOAPHeaderPayload, Equatable {
    /// Creates an empty header payload.
    public init() {}
}
