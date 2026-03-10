import Foundation

/// A decoded SOAP `<Fault>` element, carrying the error code, human-readable string,
/// optional actor URI, and optional typed detail payload.
///
/// `SOAPFault` is the associated value of ``SOAPOperationResponse/fault(_:)``.
/// The codec decodes the `<Fault>` from the response envelope body and populates
/// all four fields according to the SOAP 1.1 specification.
///
/// ## Handling a fault
/// ```swift
/// if case .fault(let fault) = response {
///     print("Code:", fault.faultCode)
///     print("Message:", fault.faultString)
/// }
/// ```
///
/// - SeeAlso: ``SOAPFaultCode``, ``SOAPFaultDetailPayload``
public struct SOAPFault<DetailPayload: SOAPFaultDetailPayload>: Sendable, Codable {
    /// The SOAP fault code (e.g. `.client`, `.server`, or a custom value).
    public let faultCode: SOAPFaultCode
    /// A human-readable description of the fault. Always non-empty after validation.
    public let faultString: String
    /// The URI identifying who caused the fault (optional; used in intermediary chains).
    public let faultActor: String?
    /// Optional structured detail payload decoded from the `<detail>` child element.
    public let detail: DetailPayload?

    #if swift(>=6.0)
    /// Creates a SOAP fault with a pre-parsed ``SOAPFaultCode``.
    ///
    /// - Parameters:
    ///   - faultCode: The fault code.
    ///   - faultString: A human-readable fault message. Must be non-empty after trimming.
    ///   - faultActor: An optional URI identifying the fault actor.
    ///   - detail: An optional structured fault detail payload.
    /// - Throws: ``SOAPCoreError/invalidFault(message:)`` if `faultString` is empty.
    public init(
        faultCode: SOAPFaultCode,
        faultString: String,
        faultActor: String? = nil,
        detail: DetailPayload? = nil
    ) throws(SOAPCoreError) {
        let cleanedFaultString = faultString.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedFaultActor = faultActor?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedFaultString.isEmpty else {
            throw SOAPCoreError.invalidFault(message: "Fault string cannot be empty.")
        }

        self.faultCode = faultCode
        self.faultString = cleanedFaultString
        self.faultActor = (cleanedFaultActor?.isEmpty == true) ? nil : cleanedFaultActor
        self.detail = detail
    }

    /// Creates a SOAP fault by parsing the fault code from a raw string.
    ///
    /// - Parameters:
    ///   - faultCode: The raw fault code string (e.g. `"env:Client"`).
    ///   - faultString: A human-readable fault message. Must be non-empty after trimming.
    ///   - faultActor: An optional URI identifying the fault actor.
    ///   - detail: An optional structured fault detail payload.
    /// - Throws: ``SOAPCoreError/invalidFault(message:)`` if the string or code is invalid.
    public init(
        faultCode: String,
        faultString: String,
        faultActor: String? = nil,
        detail: DetailPayload? = nil
    ) throws(SOAPCoreError) {
        let parsedFaultCode = try SOAPFaultCode(rawValue: faultCode)
        try self.init(
            faultCode: parsedFaultCode,
            faultString: faultString,
            faultActor: faultActor,
            detail: detail
        )
    }
    #else
    /// Creates a SOAP fault with a pre-parsed ``SOAPFaultCode``.
    ///
    /// - Parameters:
    ///   - faultCode: The fault code.
    ///   - faultString: A human-readable fault message. Must be non-empty after trimming.
    ///   - faultActor: An optional URI identifying the fault actor.
    ///   - detail: An optional structured fault detail payload.
    /// - Throws: ``SOAPCoreError/invalidFault(message:)`` if `faultString` is empty.
    public init(
        faultCode: SOAPFaultCode,
        faultString: String,
        faultActor: String? = nil,
        detail: DetailPayload? = nil
    ) throws {
        let cleanedFaultString = faultString.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedFaultActor = faultActor?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedFaultString.isEmpty else {
            throw SOAPCoreError.invalidFault(message: "Fault string cannot be empty.")
        }

        self.faultCode = faultCode
        self.faultString = cleanedFaultString
        self.faultActor = (cleanedFaultActor?.isEmpty == true) ? nil : cleanedFaultActor
        self.detail = detail
    }

    /// Creates a SOAP fault by parsing the fault code from a raw string.
    ///
    /// - Parameters:
    ///   - faultCode: The raw fault code string (e.g. `"env:Client"`).
    ///   - faultString: A human-readable fault message. Must be non-empty after trimming.
    ///   - faultActor: An optional URI identifying the fault actor.
    ///   - detail: An optional structured fault detail payload.
    /// - Throws: ``SOAPCoreError/invalidFault(message:)`` if the string or code is invalid.
    public init(
        faultCode: String,
        faultString: String,
        faultActor: String? = nil,
        detail: DetailPayload? = nil
    ) throws {
        let parsedFaultCode = try SOAPFaultCode(rawValue: faultCode)
        try self.init(
            faultCode: parsedFaultCode,
            faultString: faultString,
            faultActor: faultActor,
            detail: detail
        )
    }
    #endif
}

extension SOAPFault: Equatable where DetailPayload: Equatable {}
