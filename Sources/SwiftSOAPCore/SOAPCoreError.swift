import SwiftSOAPCompatibility

public enum SOAPCoreError: Error {
    case invalidEnvelope(message: String?)
    case invalidBodyConfiguration(message: String?)
    case invalidPayload(message: String?)
    case invalidFault(message: String?)
    case invalidAttachmentReference(message: String?)
    case missingAttachmentReference(contentID: String, message: String?)
    case unsupportedBinding(message: String?)
    case semanticValidationFailed(field: String, code: String, message: String?)
    case other(underlyingError: SOAPAnyError?, message: String?)
}
