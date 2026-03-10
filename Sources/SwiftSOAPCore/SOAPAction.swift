/// A normalised SOAP action identifier, corresponding to the `SOAPAction` HTTP header
/// in SOAP 1.1 or the `action` parameter in the SOAP 1.2 `Content-Type` header.
///
/// Use `SOAPAction` as the value of ``SOAPOperationContract/soapAction`` to declare
/// the action string required by a service endpoint. The raw value is normalised
/// (trimmed and validated) on construction via ``SOAPAction/Logic``.
///
/// ## Creating a SOAPAction
/// `SOAPAction` is typically constructed at compile time from a string literal:
/// ```swift
/// static var soapAction: SOAPAction? {
///     SOAPAction(rawValue: "http://example.com/IService/GetWeather")
/// }
/// ```
public struct SOAPAction: Sendable, Hashable, Codable {
    let normalizedRawValue: String

    /// The normalised string value of the SOAP action.
    public var rawValue: String {
        normalizedRawValue
    }
}
