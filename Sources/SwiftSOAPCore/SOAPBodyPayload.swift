/// A marker protocol for types that model the contents of a SOAP `<Body>` element.
///
/// Any `Codable` + `Sendable` type can conform to `SOAPBodyPayload`. The codec
/// layer uses this conformance as the associated type constraint on
/// ``SOAPOperationContract/RequestPayload`` and ``SOAPOperationContract/ResponsePayload``.
///
/// Field-to-element mapping is controlled by ``XMLFieldCoding`` property wrappers
/// (`@XMLElement`, `@XMLAttribute`) or by the `@XMLCodable` macro.
///
/// - SeeAlso: ``SOAPEmptyPayload`` for operations that carry no body content.
public protocol SOAPBodyPayload: Codable, Sendable {}

/// A concrete ``SOAPBodyPayload`` that represents an empty `<Body>` element.
///
/// Use `SOAPEmptyPayload` as the `RequestPayload` or `ResponsePayload` associated
/// type when an operation sends or receives no body content.
///
/// - Example:
/// ```swift
/// struct PingOperation: SOAPOperationContract {
///     typealias RequestPayload = SOAPEmptyPayload
///     typealias ResponsePayload = SOAPEmptyPayload
///     typealias FaultDetailPayload = SOAPEmptyFaultDetailPayload
///     static let operationIdentifier = SOAPOperationIdentifier(rawValue: "Ping")
/// }
/// ```
public struct SOAPEmptyPayload: SOAPBodyPayload, Equatable {
    /// Creates an empty body payload.
    public init() {}
}
