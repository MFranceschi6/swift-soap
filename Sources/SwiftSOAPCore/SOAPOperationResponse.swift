/// The result of a SOAP operation invocation: either a successful response payload
/// or a decoded SOAP fault.
///
/// `SOAPOperationResponse` is returned by the client invoke API and mirrors the
/// two possible outcomes of any SOAP call:
/// - `.success` — the server returned a valid response body.
/// - `.fault` — the server returned a `<Fault>` element in the response body.
///
/// Both cases carry fully typed, decoded Swift values; you never need to inspect
/// raw XML at this level.
///
/// ## Pattern matching
/// ```swift
/// let response = try await client.invoke(GetWeatherOperation.self, request: req, endpointURL: url)
/// switch response {
/// case .success(let weather):
///     print("Temperature:", weather.temperature)
/// case .fault(let fault):
///     print("SOAP fault:", fault.faultString)
/// }
/// ```
// swiftlint:disable:next line_length
public enum SOAPOperationResponse<ResponsePayload: SOAPBodyPayload, FaultDetailPayload: SOAPFaultDetailPayload>: Sendable, Codable {
    /// The operation completed successfully. The associated value is the decoded response payload.
    case success(ResponsePayload)
    /// The server returned a SOAP fault. The associated value carries the fault code,
    /// string, actor, and optional typed detail payload.
    case fault(SOAPFault<FaultDetailPayload>)
}
