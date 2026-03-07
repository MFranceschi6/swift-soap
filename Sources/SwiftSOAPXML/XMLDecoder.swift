import Foundation

public struct XMLDecoder: Sendable {
    public enum DateDecodingStrategy: Sendable {
        case deferredToDate
        case secondsSince1970
        case millisecondsSince1970
        case xsdDateTimeISO8601
        case iso8601
        case formatter(XMLDateFormatterDescriptor)
        case multiple([DateDecodingStrategy])
        case custom(XMLDateDecodingClosure)
    }

    public enum DataDecodingStrategy: Sendable, Hashable {
        case deferredToData
        case base64
        case hex
    }

    public struct Configuration: Sendable {
        public let rootElementName: String?
        public let itemElementName: String
        public let fieldCodingOverrides: XMLFieldCodingOverrides
        public let dateDecodingStrategy: DateDecodingStrategy
        public let dataDecodingStrategy: DataDecodingStrategy
        public let parserConfiguration: XMLTreeParser.Configuration

        public init(
            rootElementName: String? = nil,
            itemElementName: String = "item",
            fieldCodingOverrides: XMLFieldCodingOverrides = XMLFieldCodingOverrides(),
            dateDecodingStrategy: DateDecodingStrategy = .multiple(
                [.xsdDateTimeISO8601, .secondsSince1970, .millisecondsSince1970]
            ),
            dataDecodingStrategy: DataDecodingStrategy = .base64,
            parserConfiguration: XMLTreeParser.Configuration = XMLTreeParser.Configuration()
        ) {
            self.rootElementName = rootElementName
            self.itemElementName = itemElementName
            self.fieldCodingOverrides = fieldCodingOverrides
            self.dateDecodingStrategy = dateDecodingStrategy
            self.dataDecodingStrategy = dataDecodingStrategy
            self.parserConfiguration = parserConfiguration
        }
    }

    public let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    #if swift(>=6.0)
    public func decodeTree<T: Decodable>(_ type: T.Type, from tree: XMLTreeDocument) throws(XMLParsingError) -> T {
        do {
            return try decodeTreeImpl(type, from: tree)
        } catch let error as XMLParsingError {
            throw error
        } catch {
            throw XMLParsingError.other(underlyingError: error, message: "Unexpected XML decode tree error.")
        }
    }

    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws(XMLParsingError) -> T {
        do {
            let parser = XMLTreeParser(configuration: configuration.parserConfiguration)
            let tree = try parser.parse(data: data)
            return try decodeTreeImpl(type, from: tree)
        } catch let error as XMLParsingError {
            throw error
        } catch {
            throw XMLParsingError.other(underlyingError: error, message: "Unexpected XML decode error.")
        }
    }
    #else
    public func decodeTree<T: Decodable>(_ type: T.Type, from tree: XMLTreeDocument) throws -> T {
        try decodeTreeImpl(type, from: tree)
    }

    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let parser = XMLTreeParser(configuration: configuration.parserConfiguration)
        let tree = try parser.parse(data: data)
        return try decodeTreeImpl(type, from: tree)
    }
    #endif

    private func decodeTreeImpl<T: Decodable>(_ type: T.Type, from tree: XMLTreeDocument) throws -> T {
        if let expectedRootName = try resolveExpectedRootElementName(for: type),
           tree.root.name.localName != expectedRootName {
            throw XMLParsingError.parseFailed(
                message: "[XML6_5_ROOT_MISMATCH] Expected root '\(expectedRootName)' but found '\(tree.root.name.localName)'."
            )
        }

        let options = _XMLDecoderOptions(configuration: configuration)
        let decoder = _XMLTreeDecoder(
            options: options,
            codingPath: [],
            node: tree.root,
            fieldNodeKinds: _xmlFieldNodeKinds(for: T.self)
        )
        return try T(from: decoder)
    }

    private func resolveExpectedRootElementName<T>(for type: T.Type) throws -> String? {
        if let explicitName = XMLRootNameResolver.explicitRootElementName(from: configuration.rootElementName) {
            return explicitName
        }

        return try XMLRootNameResolver.implicitRootElementName(for: type)
    }
}
