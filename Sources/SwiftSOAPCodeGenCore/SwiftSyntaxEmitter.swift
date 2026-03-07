#if canImport(SwiftSyntaxBuilder)
import Foundation
import SwiftSyntaxBuilder

public struct SwiftSyntaxEmitter: SwiftSourceEmitter {
    private let fallbackEmitter: SwiftCodeEmitter

    public init(fallbackEmitter: SwiftCodeEmitter = SwiftCodeEmitter()) {
        self.fallbackEmitter = fallbackEmitter
    }

    public func emit(ir: SOAPCodeGenerationIR, syntaxProfile: CodeGenerationSyntaxProfile) -> String {
        // The semantic IR-to-AST migration can proceed incrementally while preserving stable output.
        fallbackEmitter.emit(ir: ir, syntaxProfile: syntaxProfile)
    }
}
#endif
