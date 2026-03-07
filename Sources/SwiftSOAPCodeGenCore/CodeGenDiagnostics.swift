public enum CodeGenDiagnosticCode: String, Sendable, Codable {
    case unresolvedReference = "CG001"
    case duplicateSymbol = "CG002"
    case unsupportedBinding = "CG003"
    case invalidConfiguration = "CG004"
    case unresolvedImport = "CG005"
    case invalidInput = "CG006"
    case unsupportedSwiftTarget = "CG007"
    case invalidSyntaxFeature = "CG008"
}

public struct CodeGenError: Error, Sendable, Equatable {
    public let code: CodeGenDiagnosticCode
    public let message: String
    public let suggestion: String?

    public init(code: CodeGenDiagnosticCode, message: String, suggestion: String? = nil) {
        self.code = code
        self.message = message
        self.suggestion = suggestion
    }
}

extension CodeGenError: CustomStringConvertible {
    public var description: String {
        if let suggestion = suggestion {
            return "[\(code.rawValue)] \(message) Suggestion: \(suggestion)"
        }
        return "[\(code.rawValue)] \(message)"
    }
}
