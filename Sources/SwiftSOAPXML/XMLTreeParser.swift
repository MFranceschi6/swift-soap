import Foundation
import SwiftSOAPCompatibility
import SwiftSOAPXMLCShim

public struct XMLTreeParser: Sendable {
    public enum WhitespaceTextNodePolicy: Sendable, Hashable {
        case preserve
        case dropWhitespaceOnly
        case trim
        case normalizeAndTrim
    }

    public struct Limits: Sendable, Hashable {
        public let maxInputBytes: Int?
        public let maxDepth: Int
        public let maxNodeCount: Int?
        public let maxAttributesPerElement: Int?
        public let maxTextNodeBytes: Int?
        public let maxCDATABlockBytes: Int?

        public init(
            maxInputBytes: Int? = nil,
            maxDepth: Int = 4096,
            maxNodeCount: Int? = nil,
            maxAttributesPerElement: Int? = nil,
            maxTextNodeBytes: Int? = nil,
            maxCDATABlockBytes: Int? = nil
        ) {
            self.maxInputBytes = maxInputBytes
            self.maxDepth = max(1, maxDepth)
            self.maxNodeCount = maxNodeCount
            self.maxAttributesPerElement = maxAttributesPerElement
            self.maxTextNodeBytes = maxTextNodeBytes
            self.maxCDATABlockBytes = maxCDATABlockBytes
        }

        public static func untrustedInputDefault() -> Limits {
            Limits(
                maxInputBytes: 16 * 1024 * 1024,
                maxDepth: 256,
                maxNodeCount: 200_000,
                maxAttributesPerElement: 256,
                maxTextNodeBytes: 1 * 1024 * 1024,
                maxCDATABlockBytes: 4 * 1024 * 1024
            )
        }
    }

    public struct Configuration: Sendable, Hashable {
        public let whitespaceTextNodePolicy: WhitespaceTextNodePolicy
        public let parsingConfiguration: XMLDocument.ParsingConfiguration
        public let limits: Limits

        public var preserveWhitespaceTextNodes: Bool {
            whitespaceTextNodePolicy == .preserve
        }

        public init(
            preserveWhitespaceTextNodes: Bool = false,
            whitespaceTextNodePolicy: WhitespaceTextNodePolicy? = nil,
            parsingConfiguration: XMLDocument.ParsingConfiguration = XMLDocument.ParsingConfiguration(),
            limits: Limits = Limits()
        ) {
            self.whitespaceTextNodePolicy = whitespaceTextNodePolicy ?? (
                preserveWhitespaceTextNodes ? .preserve : .dropWhitespaceOnly
            )
            self.parsingConfiguration = parsingConfiguration
            self.limits = limits
        }

        public static func untrustedInputProfile(
            preserveWhitespaceTextNodes: Bool = false,
            whitespaceTextNodePolicy: WhitespaceTextNodePolicy? = nil
        ) -> Configuration {
            let resolvedWhitespacePolicy = whitespaceTextNodePolicy ?? (
                preserveWhitespaceTextNodes ? .preserve : .dropWhitespaceOnly
            )
            return Configuration(
                preserveWhitespaceTextNodes: preserveWhitespaceTextNodes,
                whitespaceTextNodePolicy: resolvedWhitespacePolicy,
                parsingConfiguration: XMLDocument.ParsingConfiguration(
                    trimBlankTextNodes: resolvedWhitespacePolicy != .preserve,
                    externalResourceLoadingPolicy: .forbidNetwork,
                    dtdLoadingPolicy: .forbid,
                    entityDecodingPolicy: .preserveReferences
                ),
                limits: .untrustedInputDefault()
            )
        }
    }

    struct ParseState {
        var nodeCount: Int = 0
    }

    public let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    #if swift(>=6.0)
    public func parse(data: Data) throws(XMLParsingError) -> XMLTreeDocument {
        do {
            try ensureLimit(
                actual: data.count,
                limit: configuration.limits.maxInputBytes,
                code: "XML6_2H_MAX_INPUT_BYTES",
                context: "XML input bytes"
            )

            let document = try XMLDocument(
                data: data,
                parsingConfiguration: effectiveParsingConfiguration()
            )
            return try parse(document: document)
        } catch let error as XMLParsingError {
            throw error
        } catch {
            throw XMLParsingError.other(underlyingError: error, message: "Unexpected XML tree parse error.")
        }
    }

    public func parse(document: XMLDocument) throws(XMLParsingError) -> XMLTreeDocument {
        do {
            return try parseDocument(document)
        } catch let error as XMLParsingError {
            throw error
        } catch {
            throw XMLParsingError.other(underlyingError: error, message: "Unexpected XML tree parse error.")
        }
    }
    #else
    public func parse(data: Data) throws -> XMLTreeDocument {
        try ensureLimit(
            actual: data.count,
            limit: configuration.limits.maxInputBytes,
            code: "XML6_2H_MAX_INPUT_BYTES",
            context: "XML input bytes"
        )

        let document = try XMLDocument(
            data: data,
            parsingConfiguration: effectiveParsingConfiguration()
        )
        return try parse(document: document)
    }

    public func parse(document: XMLDocument) throws -> XMLTreeDocument {
        try parseDocument(document)
    }
    #endif
}
