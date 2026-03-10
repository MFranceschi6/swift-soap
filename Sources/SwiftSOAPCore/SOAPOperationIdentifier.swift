/// A stable, normalised identifier for a SOAP operation.
///
/// `SOAPOperationIdentifier` wraps the operation name string from the WSDL
/// `<operation name="…">` attribute. The raw value is normalised on construction
/// to ensure reliable equality and hashing across operations.
///
/// Used as the value of ``SOAPOperationContract/operationIdentifier`` to uniquely
/// identify an operation within a service.
///
/// ## Creating an identifier
/// ```swift
/// static let operationIdentifier = SOAPOperationIdentifier(rawValue: "GetWeather")
/// ```
public struct SOAPOperationIdentifier: Sendable, Hashable, Codable {
    let normalizedRawValue: String

    /// The normalised string value of the operation identifier.
    public var rawValue: String {
        normalizedRawValue
    }
}
