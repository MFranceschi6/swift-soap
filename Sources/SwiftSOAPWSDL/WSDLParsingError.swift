import SwiftSOAPCompatibility

public enum WSDLParsingError: Error {
    case invalidDocument(message: String?)
    case invalidSchema(name: String?, message: String?)
    case invalidMessage(name: String?, message: String?)
    case invalidPortType(name: String?, message: String?)
    case invalidOperation(name: String?, message: String?)
    case invalidBinding(name: String?, message: String?)
    case invalidService(name: String?, message: String?)
    case invalidServicePort(name: String?, message: String?)
    case other(underlyingError: SOAPAnyError?, message: String?)
}
