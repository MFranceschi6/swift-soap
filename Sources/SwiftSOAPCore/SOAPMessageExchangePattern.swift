/// The SOAP Message Exchange Pattern (MEP) for a given operation.
///
/// SOAP defines several patterns of interaction between service endpoints.
/// This type covers the two patterns supported by this library; unsupported patterns
/// are diagnosed at code-generation time.
///
/// - SeeAlso: ``SOAPOperationContract``
public enum SOAPMessageExchangePattern: Sendable, Equatable {
    /// The client sends a request and the service returns a response (or a fault).
    ///
    /// This is the most common SOAP interaction. Corresponds to a WSDL operation
    /// that has both an `input` and an `output` element.
    case requestResponse

    /// The client sends a message and the service does not return a response payload.
    ///
    /// Corresponds to a WSDL operation that has only an `input` element and no `output`.
    /// The service may still return a SOAP fault if something goes wrong.
    case oneWay
}
