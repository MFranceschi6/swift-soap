/// Protocol implemented by Swift source code emitters.
///
/// An emitter transforms a `SOAPCodeGenerationIR` into a Swift source string
/// using the given syntax profile (target Swift version, language features).
public protocol SwiftSourceEmitter {
    func emit(ir: SOAPCodeGenerationIR, syntaxProfile: CodeGenerationSyntaxProfile) -> String
}
