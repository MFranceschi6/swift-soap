import Foundation

public enum XMLParsingError: Error {
    case invalidUTF8
    case parseFailed(message: String?)
    case xpathFailed(expression: String, message: String?)
    case documentCreationFailed(message: String?)
    case nodeCreationFailed(name: String, message: String?)
    case invalidNamespaceConfiguration(prefix: String?, uri: String?)
    case nodeOperationFailed(message: String?)
    case other(underlyingError: Error?, message: String?)
}
