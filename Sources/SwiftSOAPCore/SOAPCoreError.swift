import SwiftSOAPCompatibility

/// Errors produced by the SOAP core codec and envelope processing layer.
///
/// `SOAPCoreError` is thrown by ``SOAPXMLWireCodec``, ``SOAPEnvelope``, ``SOAPFault``,
/// and related types when a structural or semantic violation is detected during
/// encoding or decoding of SOAP messages.
public enum SOAPCoreError: Error {
    /// The SOAP envelope structure is malformed or unrecognised.
    ///
    /// - Parameter message: A human-readable description of the violation, if available.
    case invalidEnvelope(message: String?)

    /// The `<Body>` element configuration is invalid (e.g. both payload and fault present).
    ///
    /// - Parameter message: A human-readable description of the violation, if available.
    case invalidBodyConfiguration(message: String?)

    /// The body or fault detail payload could not be encoded or decoded.
    ///
    /// - Parameter message: A human-readable description of the violation, if available.
    case invalidPayload(message: String?)

    /// The `<Fault>` element is structurally invalid (e.g. an empty fault string).
    ///
    /// - Parameter message: A human-readable description of the violation, if available.
    case invalidFault(message: String?)

    /// An XOP/MTOM or SwA attachment reference in the XML is malformed.
    ///
    /// - Parameter message: A human-readable description of the violation, if available.
    case invalidAttachmentReference(message: String?)

    /// An attachment content-ID referenced from the XML is not present in the transport message.
    ///
    /// - Parameters:
    ///   - contentID: The `cid:` reference that was expected but not found.
    ///   - message: A human-readable description of the violation, if available.
    case missingAttachmentReference(contentID: String, message: String?)

    /// The SOAP binding metadata combination is not supported by the selected codec strategy.
    ///
    /// - Parameter message: A human-readable description of the violation, if available.
    case unsupportedBinding(message: String?)

    /// A semantic validation rule (e.g. from ``SOAPSemanticValidatable``) was violated.
    ///
    /// - Parameters:
    ///   - field: The name of the field or path where the violation occurred.
    ///   - code: A stable diagnostic code identifying the rule that failed.
    ///   - message: A human-readable description of the violation, if available.
    case semanticValidationFailed(field: String, code: String, message: String?)

    /// A catch-all case for unexpected errors not covered by more specific cases.
    ///
    /// - Parameters:
    ///   - underlyingError: The original error, wrapped in a type-erased container, if available.
    ///   - message: A human-readable description of the situation, if available.
    case other(underlyingError: SOAPAnyError?, message: String?)
}
