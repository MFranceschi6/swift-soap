/// A marker protocol for types that model the contents of the `<detail>` element
/// inside a SOAP `<Fault>`.
///
/// Conform any `Codable` + `Sendable` type to `SOAPFaultDetailPayload` to carry
/// service-specific fault detail information. The codec layer decodes the `<detail>`
/// child into this type when a SOAP fault is received.
///
/// - SeeAlso: ``SOAPFault`` which wraps the fault code, string, actor, and detail.
/// - SeeAlso: ``SOAPEmptyFaultDetailPayload`` when no detail structure is expected.
public protocol SOAPFaultDetailPayload: Codable, Sendable {}

/// A concrete ``SOAPFaultDetailPayload`` that represents a missing or empty `<detail>` element.
///
/// Use `SOAPEmptyFaultDetailPayload` as the `FaultDetailPayload` associated type
/// on ``SOAPOperationContract`` when the service either omits the fault detail
/// or when you intentionally discard it.
public struct SOAPEmptyFaultDetailPayload: SOAPFaultDetailPayload, Equatable {
    /// Creates an empty fault detail payload.
    public init() {}
}
