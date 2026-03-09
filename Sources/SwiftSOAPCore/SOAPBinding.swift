public enum SOAPBindingEnvelopeVersion: String, Sendable, Codable, CaseIterable {
    case soap11
    case soap12
}

public enum SOAPBindingStyle: String, Sendable, Codable, CaseIterable {
    case document
    case rpc
}

public enum SOAPBindingBodyUse: String, Sendable, Codable, CaseIterable {
    case literal
    case encoded
}

public struct SOAPBindingMetadata: Sendable, Codable, Equatable {
    public let envelopeVersion: SOAPBindingEnvelopeVersion
    public let style: SOAPBindingStyle
    public let bodyUse: SOAPBindingBodyUse

    public init(
        envelopeVersion: SOAPBindingEnvelopeVersion,
        style: SOAPBindingStyle,
        bodyUse: SOAPBindingBodyUse
    ) {
        self.envelopeVersion = envelopeVersion
        self.style = style
        self.bodyUse = bodyUse
    }
}

public protocol SOAPBindingCodecStrategy: Sendable {
    func validate(metadata: SOAPBindingMetadata) throws
}

public struct SOAPDocumentLiteralCodecStrategy: SOAPBindingCodecStrategy {
    public init() {}

    public func validate(metadata: SOAPBindingMetadata) throws {
        guard metadata.style == .document, metadata.bodyUse == .literal else {
            throw SOAPCoreError.unsupportedBinding(
                message: "Document/literal codec cannot validate metadata '\(metadata.style.rawValue)/\(metadata.bodyUse.rawValue)'."
            )
        }
    }
}

public struct SOAPRPCLiteralCodecStrategy: SOAPBindingCodecStrategy {
    public init() {}

    public func validate(metadata: SOAPBindingMetadata) throws {
        guard metadata.style == .rpc, metadata.bodyUse == .literal else {
            throw SOAPCoreError.unsupportedBinding(
                message: "RPC/literal codec cannot validate metadata '\(metadata.style.rawValue)/\(metadata.bodyUse.rawValue)'."
            )
        }
    }
}

public struct SOAPRPCEncodedCodecStrategy: SOAPBindingCodecStrategy {
    public init() {}

    public func validate(metadata: SOAPBindingMetadata) throws {
        guard metadata.style == .rpc, metadata.bodyUse == .encoded else {
            throw SOAPCoreError.unsupportedBinding(
                message: "RPC/encoded codec cannot validate metadata '\(metadata.style.rawValue)/\(metadata.bodyUse.rawValue)'."
            )
        }
    }
}

public enum SOAPBindingCodecFactory {
    public static func makeCodecStrategy(for metadata: SOAPBindingMetadata) -> any SOAPBindingCodecStrategy {
        switch (metadata.style, metadata.bodyUse) {
        case (.document, .literal):
            return SOAPDocumentLiteralCodecStrategy()
        case (.rpc, .literal):
            return SOAPRPCLiteralCodecStrategy()
        case (.rpc, .encoded):
            return SOAPRPCEncodedCodecStrategy()
        case (.document, .encoded):
            return SOAPRPCEncodedCodecStrategy()
        }
    }
}
