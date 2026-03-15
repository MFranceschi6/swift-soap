/// The central definition of a SOAP operation that the client or server stack can invoke.
///
/// Conform your operation type to `SOAPOperationContract` to describe the complete
/// type contract of a single SOAP web-service call: what you send (`RequestPayload`),
/// what you receive back on success (`ResponsePayload`), and what arrives in a fault
/// (`FaultDetailPayload`).
///
/// The codec layer (``SOAPXMLWireCodec``) uses the associated types and static
/// properties to encode requests and decode responses without any runtime type erasure.
///
/// ## Minimal example
/// ```swift
/// struct GetWeatherOperation: SOAPOperationContract {
///     struct Request: SOAPBodyPayload {
///         var cityName: String
///     }
///     struct Response: SOAPBodyPayload {
///         var temperature: Double
///     }
///     typealias FaultDetailPayload = SOAPEmptyFaultDetailPayload
///
///     static let operationIdentifier = SOAPOperationIdentifier(rawValue: "GetWeather")
///     // soapAction defaults to nil — set it when the WSDL specifies a SOAPAction
/// }
/// ```
///
/// ## Binding metadata
/// If the service uses a non-default binding (e.g. RPC/literal), conform additionally
/// to ``SOAPBindingOperationContract`` to supply ``SOAPBindingMetadata``.
///
/// - SeeAlso: ``SOAPBindingOperationContract``, ``SOAPXMLWireCodec``
public protocol SOAPOperationContract: Sendable {
    /// The type used to serialise the request body payload.
    associatedtype RequestPayload: SOAPBodyPayload
    /// The type used to deserialise the successful response body payload.
    associatedtype ResponsePayload: SOAPBodyPayload
    /// The type used to deserialise the `<detail>` element inside a SOAP fault.
    associatedtype FaultDetailPayload: SOAPFaultDetailPayload

    /// A stable, unique identifier for this operation.
    ///
    /// Typically derived from the WSDL `<operation name="…">` attribute.
    static var operationIdentifier: SOAPOperationIdentifier { get }

    /// The SOAP 1.1 `SOAPAction` HTTP header value for this operation, or `nil` if not required.
    ///
    /// Defaults to `nil` via the extension in ``SOAPOperationContract+Defaults``.
    static var soapAction: SOAPAction? { get }

    /// The SOAP Message Exchange Pattern (MEP) for this operation.
    ///
    /// Defaults to `.requestResponse`. Override this to `.oneWay` for operations
    /// that send a request but do not expect a response payload.
    ///
    /// - SeeAlso: ``SOAPMessageExchangePattern``
    static var messageExchangePattern: SOAPMessageExchangePattern { get }
}
