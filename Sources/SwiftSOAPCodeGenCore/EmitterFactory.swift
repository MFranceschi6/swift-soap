import Foundation

public enum EmitterFactory {
    public static func makeEmitter() -> any SwiftSourceEmitter {
        #if canImport(SwiftSyntaxBuilder)
        return SwiftSyntaxEmitter()
        #else
        return SwiftCodeEmitter()
        #endif
    }
}
