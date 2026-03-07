import Foundation

public struct XMLEncoder: Sendable {
    public enum NilEncodingStrategy: Sendable, Hashable {
        case emptyElement
        case omitElement
    }

    public enum DateEncodingStrategy: Sendable {
        case deferredToDate
        case secondsSince1970
        case millisecondsSince1970
        case xsdDateTimeISO8601
        case iso8601
        case formatter(XMLDateFormatterDescriptor)
        case custom(XMLDateEncodingClosure)
    }

    public enum DataEncodingStrategy: Sendable, Hashable {
        case deferredToData
        case base64
        case hex
    }

    public struct Configuration: Sendable {
        public let rootElementName: String?
        public let itemElementName: String
        public let nilEncodingStrategy: NilEncodingStrategy
        public let dateEncodingStrategy: DateEncodingStrategy
        public let dataEncodingStrategy: DataEncodingStrategy
        public let writerConfiguration: XMLTreeWriter.Configuration

        public init(
            rootElementName: String? = nil,
            itemElementName: String = "item",
            nilEncodingStrategy: NilEncodingStrategy = .emptyElement,
            dateEncodingStrategy: DateEncodingStrategy = .xsdDateTimeISO8601,
            dataEncodingStrategy: DataEncodingStrategy = .base64,
            writerConfiguration: XMLTreeWriter.Configuration = XMLTreeWriter.Configuration()
        ) {
            self.rootElementName = rootElementName
            self.itemElementName = itemElementName
            self.nilEncodingStrategy = nilEncodingStrategy
            self.dateEncodingStrategy = dateEncodingStrategy
            self.dataEncodingStrategy = dataEncodingStrategy
            self.writerConfiguration = writerConfiguration
        }
    }

    public let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    #if swift(>=6.0)
    public func encodeTree<T: Encodable>(_ value: T) throws(XMLParsingError) -> XMLTreeDocument {
        do {
            return try encodeTreeImpl(value)
        } catch let error as XMLParsingError {
            throw error
        } catch {
            throw XMLParsingError.other(underlyingError: error, message: "Unexpected XML encode tree error.")
        }
    }

    public func encode<T: Encodable>(_ value: T) throws(XMLParsingError) -> Data {
        do {
            let tree = try encodeTreeImpl(value)
            let writer = XMLTreeWriter(configuration: configuration.writerConfiguration)
            return try writer.writeData(tree)
        } catch let error as XMLParsingError {
            throw error
        } catch {
            throw XMLParsingError.other(underlyingError: error, message: "Unexpected XML encode error.")
        }
    }
    #else
    public func encodeTree<T: Encodable>(_ value: T) throws -> XMLTreeDocument {
        try encodeTreeImpl(value)
    }

    public func encode<T: Encodable>(_ value: T) throws -> Data {
        let tree = try encodeTreeImpl(value)
        let writer = XMLTreeWriter(configuration: configuration.writerConfiguration)
        return try writer.writeData(tree)
    }
    #endif

    private func encodeTreeImpl<T: Encodable>(_ value: T) throws -> XMLTreeDocument {
        let rootElementName = resolveRootElementName(for: T.self)
        let rootNode = _XMLTreeElementBox(name: XMLQualifiedName(localName: rootElementName))
        let options = _XMLEncoderOptions(configuration: configuration)
        let encoder = _XMLTreeEncoder(options: options, codingPath: [], node: rootNode)
        try value.encode(to: encoder)
        return XMLTreeDocument(root: rootNode.makeElement())
    }

    private func resolveRootElementName<T>(for type: T.Type) -> String {
        if let explicitName = configuration.rootElementName?.trimmingCharacters(in: .whitespacesAndNewlines),
           explicitName.isEmpty == false {
            return Self.makeXMLSafeName(explicitName)
        }

        let typeName = String(describing: type)
        let shortName = typeName.split(separator: ".").last.map(String.init) ?? "Root"
        return Self.makeXMLSafeName(shortName)
    }

    private static func makeXMLSafeName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        var result = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        }

        if result.isEmpty {
            result = Array("Root")
        }

        if let first = result.first, first.isNumber {
            result.insert("_", at: result.startIndex)
        }

        return String(result)
    }
}
