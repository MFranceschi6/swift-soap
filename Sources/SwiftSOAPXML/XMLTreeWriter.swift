import Foundation
import SwiftSOAPCompatibility
import SwiftSOAPXMLCShim

public struct XMLTreeWriter: Sendable {
    public enum AttributeOrderingPolicy: Sendable, Hashable {
        case preserve
        case lexicographical
    }

    public enum NamespaceDeclarationOrderingPolicy: Sendable, Hashable {
        case preserve
        case lexicographical
    }

    public enum WhitespaceTextNodePolicy: Sendable, Hashable {
        case preserve
        case omitWhitespaceOnly
        case trim
        case normalizeAndTrim
    }

    public enum DeterministicSerializationMode: Sendable, Hashable {
        case disabled
        case stable
    }

    public enum NamespaceValidationMode: Sendable, Hashable {
        case strict
        case synthesizeMissingDeclarations

        var validatorMode: XMLNamespaceValidator.Mode {
            switch self {
            case .strict:
                return .strict
            case .synthesizeMissingDeclarations:
                return .synthesizeMissingDeclarations
            }
        }
    }

    public struct Limits: Sendable, Hashable {
        public let maxDepth: Int
        public let maxNodeCount: Int?
        public let maxOutputBytes: Int?
        public let maxTextNodeBytes: Int?
        public let maxCDATABlockBytes: Int?
        public let maxCommentBytes: Int?

        public init(
            maxDepth: Int = 4096,
            maxNodeCount: Int? = nil,
            maxOutputBytes: Int? = nil,
            maxTextNodeBytes: Int? = nil,
            maxCDATABlockBytes: Int? = nil,
            maxCommentBytes: Int? = nil
        ) {
            self.maxDepth = max(1, maxDepth)
            self.maxNodeCount = maxNodeCount
            self.maxOutputBytes = maxOutputBytes
            self.maxTextNodeBytes = maxTextNodeBytes
            self.maxCDATABlockBytes = maxCDATABlockBytes
            self.maxCommentBytes = maxCommentBytes
        }

        public static func untrustedInputDefault() -> Limits {
            Limits(
                maxDepth: 256,
                maxNodeCount: 200_000,
                maxOutputBytes: 16 * 1024 * 1024,
                maxTextNodeBytes: 1 * 1024 * 1024,
                maxCDATABlockBytes: 4 * 1024 * 1024,
                maxCommentBytes: 256 * 1024
            )
        }
    }

    public struct Configuration: Sendable, Hashable {
        public let encoding: String
        public let prettyPrinted: Bool
        public let attributeOrderingPolicy: AttributeOrderingPolicy
        public let namespaceDeclarationOrderingPolicy: NamespaceDeclarationOrderingPolicy
        public let whitespaceTextNodePolicy: WhitespaceTextNodePolicy
        public let deterministicSerializationMode: DeterministicSerializationMode
        public let namespaceValidationMode: NamespaceValidationMode
        public let limits: Limits

        public init(
            encoding: String = "UTF-8",
            prettyPrinted: Bool = false,
            attributeOrderingPolicy: AttributeOrderingPolicy = .preserve,
            namespaceDeclarationOrderingPolicy: NamespaceDeclarationOrderingPolicy = .preserve,
            whitespaceTextNodePolicy: WhitespaceTextNodePolicy = .preserve,
            deterministicSerializationMode: DeterministicSerializationMode = .disabled,
            namespaceValidationMode: NamespaceValidationMode = .strict,
            limits: Limits = Limits()
        ) {
            self.encoding = encoding
            self.prettyPrinted = prettyPrinted
            self.attributeOrderingPolicy = attributeOrderingPolicy
            self.namespaceDeclarationOrderingPolicy = namespaceDeclarationOrderingPolicy
            self.whitespaceTextNodePolicy = whitespaceTextNodePolicy
            self.deterministicSerializationMode = deterministicSerializationMode
            self.namespaceValidationMode = namespaceValidationMode
            self.limits = limits
        }

        public static func untrustedInputProfile(
            encoding: String = "UTF-8",
            prettyPrinted: Bool = false
        ) -> Configuration {
            Configuration(
                encoding: encoding,
                prettyPrinted: prettyPrinted,
                attributeOrderingPolicy: .preserve,
                namespaceDeclarationOrderingPolicy: .preserve,
                whitespaceTextNodePolicy: .preserve,
                deterministicSerializationMode: .disabled,
                namespaceValidationMode: .strict,
                limits: .untrustedInputDefault()
            )
        }
    }

    struct WriteState {
        var nodeCount: Int = 0
    }

    public let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    #if swift(>=6.0)
    public func writeDocument(_ treeDocument: XMLTreeDocument) throws(XMLParsingError) -> XMLDocument {
        do {
            return try writeDocumentImpl(treeDocument)
        } catch let error as XMLParsingError {
            throw error
        } catch {
            throw XMLParsingError.other(underlyingError: error, message: "Unexpected XML tree writer error.")
        }
    }

    public func writeData(_ treeDocument: XMLTreeDocument) throws(XMLParsingError) -> Data {
        do {
            let xmlDocument = try writeDocument(treeDocument)
            let xmlData = try xmlDocument.serializedData(
                encoding: configuration.encoding,
                prettyPrinted: configuration.prettyPrinted
            )
            try ensureLimit(
                actual: xmlData.count,
                limit: configuration.limits.maxOutputBytes,
                code: "XML6_2H_MAX_OUTPUT_BYTES",
                context: "serialized XML output bytes"
            )
            return xmlData
        } catch let error as XMLParsingError {
            throw error
        } catch {
            throw XMLParsingError.other(underlyingError: error, message: "Unexpected XML tree writer error.")
        }
    }
    #else
    public func writeDocument(_ treeDocument: XMLTreeDocument) throws -> XMLDocument {
        try writeDocumentImpl(treeDocument)
    }

    public func writeData(_ treeDocument: XMLTreeDocument) throws -> Data {
        let xmlDocument = try writeDocument(treeDocument)
        let xmlData = try xmlDocument.serializedData(
            encoding: configuration.encoding,
            prettyPrinted: configuration.prettyPrinted
        )
        try ensureLimit(
            actual: xmlData.count,
            limit: configuration.limits.maxOutputBytes,
            code: "XML6_2H_MAX_OUTPUT_BYTES",
            context: "serialized XML output bytes"
        )
        return xmlData
    }
    #endif

}
