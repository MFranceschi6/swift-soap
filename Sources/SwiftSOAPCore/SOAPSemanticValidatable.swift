/// A protocol for types that carry XSD facet-derived runtime validation.
///
/// Types conforming to `SOAPSemanticValidatable` expose a `validate()` method
/// emitted by the code generator when `validationProfile == .strict`.
/// The wire codec invokes `validate()` automatically after decoding.
public protocol SOAPSemanticValidatable {
    /// Validates all field constraints derived from XSD facets.
    /// - Throws: `SOAPSemanticValidationError` on first constraint violation.
    func validate() throws
}

/// An error thrown by generated `validate()` methods when an XSD facet constraint is violated.
public struct SOAPSemanticValidationError: Error, Sendable {
    /// Name of the field that violated the constraint.
    public let field: String
    /// Stable diagnostic code (e.g. `[CG_SEMANTIC_001]`).
    public let code: String
    /// Human-readable description of the violation, if available.
    public let message: String?

    public init(field: String, code: String, message: String? = nil) {
        self.field = field
        self.code = code
        self.message = message
    }
}
