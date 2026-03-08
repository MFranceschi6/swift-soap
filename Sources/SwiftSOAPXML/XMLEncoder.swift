import Foundation

/// Encodes `Encodable` values into XML trees or raw XML data.
///
/// `XMLEncoder` is the primary entry point for serialising Swift model types to XML.
/// It uses the `Codable` machinery internally and supports configurable strategies
/// for nils, dates, binary data, and element ordering.
///
/// ```swift
/// let encoder = XMLEncoder()
/// let data = try encoder.encode(myValue)
/// ```
///
/// The encoder is `Sendable` and can be shared across concurrent contexts without
/// additional synchronisation.
public struct XMLEncoder: Sendable {
    /// Controls how optional (`nil`) values are represented in the XML output.
    public enum NilEncodingStrategy: Sendable, Hashable {
        /// Emit an empty element (`<field/>`). This is the default.
        case emptyElement
        /// Omit the element entirely from the output.
        case omitElement
    }

    /// Controls how `Date` values are serialised to XML text content.
    public enum DateEncodingStrategy: Sendable {
        /// Delegate to `Date`'s default `Encodable` behaviour (a Double).
        case deferredToDate
        /// Encode as seconds elapsed since Unix epoch (floating-point string).
        case secondsSince1970
        /// Encode as milliseconds elapsed since Unix epoch (floating-point string).
        case millisecondsSince1970
        /// Encode in XSD `dateTime` format (`YYYY-MM-DDThh:mm:ssZ`). This is the default.
        case xsdDateTimeISO8601
        /// Encode in ISO 8601 format as produced by `ISO8601DateFormatter`.
        case iso8601
        /// Encode using a custom `XMLDateFormatterDescriptor`.
        case formatter(XMLDateFormatterDescriptor)
        /// Encode using a custom closure.
        case custom(XMLDateEncodingClosure)
    }

    /// Controls how `Data` values are serialised to XML text content.
    public enum DataEncodingStrategy: Sendable, Hashable {
        /// Delegate to `Data`'s default `Encodable` behaviour.
        case deferredToData
        /// Encode as Base-64 text. This is the default.
        case base64
        /// Encode as lowercase hexadecimal text.
        case hex
    }

    /// Encoding configuration applied to every encode call on this instance.
    public struct Configuration: Sendable {
        /// Override the root element name.
        /// When `nil`, the encoder derives the name from `@XMLRootNode` or the type name.
        public let rootElementName: String?
        /// Element name used for items in collection types.  Defaults to `"item"`.
        public let itemElementName: String
        /// Field-level coding overrides (e.g. attribute vs element, custom element names).
        public let fieldCodingOverrides: XMLFieldCodingOverrides
        /// Strategy for encoding `nil` optionals.  Defaults to `.emptyElement`.
        public let nilEncodingStrategy: NilEncodingStrategy
        /// Strategy for encoding `Date` values.  Defaults to `.xsdDateTimeISO8601`.
        public let dateEncodingStrategy: DateEncodingStrategy
        /// Strategy for encoding `Data` values.  Defaults to `.base64`.
        public let dataEncodingStrategy: DataEncodingStrategy
        /// Configuration forwarded to the underlying `XMLTreeWriter`.
        public let writerConfiguration: XMLTreeWriter.Configuration

        public init(
            rootElementName: String? = nil,
            itemElementName: String = "item",
            fieldCodingOverrides: XMLFieldCodingOverrides = XMLFieldCodingOverrides(),
            nilEncodingStrategy: NilEncodingStrategy = .emptyElement,
            dateEncodingStrategy: DateEncodingStrategy = .xsdDateTimeISO8601,
            dataEncodingStrategy: DataEncodingStrategy = .base64,
            writerConfiguration: XMLTreeWriter.Configuration = XMLTreeWriter.Configuration()
        ) {
            self.rootElementName = rootElementName
            self.itemElementName = itemElementName
            self.fieldCodingOverrides = fieldCodingOverrides
            self.nilEncodingStrategy = nilEncodingStrategy
            self.dateEncodingStrategy = dateEncodingStrategy
            self.dataEncodingStrategy = dataEncodingStrategy
            self.writerConfiguration = writerConfiguration
        }
    }

    /// The configuration used by this encoder.
    public let configuration: Configuration

    /// Creates a new encoder with the supplied configuration.
    /// - Parameter configuration: Encoding options.  Defaults to `Configuration()`.
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    #if swift(>=6.0)
    /// Encodes `value` into an `XMLTreeDocument`.
    ///
    /// Use this when you need to inspect or manipulate the tree before serialising.
    /// - Parameter value: The value to encode.
    /// - Returns: An `XMLTreeDocument` whose root element represents `value`.
    /// - Throws: `XMLParsingError` on encoding failure.
    public func encodeTree<T: Encodable>(_ value: T) throws(XMLParsingError) -> XMLTreeDocument {
        do {
            return try encodeTreeImpl(value)
        } catch let error as XMLParsingError {
            throw error
        } catch {
            throw XMLParsingError.other(underlyingError: error, message: "Unexpected XML encode tree error.")
        }
    }

    /// Encodes `value` into raw XML `Data`.
    ///
    /// Internally encodes to an `XMLTreeDocument` and then serialises using the
    /// `writerConfiguration` from `configuration`.
    /// - Parameter value: The value to encode.
    /// - Returns: UTF-8 encoded XML data.
    /// - Throws: `XMLParsingError` on encoding or serialisation failure.
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
        let rootElementName = try resolveRootElementName(for: T.self)
        let rootNode = _XMLTreeElementBox(name: XMLQualifiedName(localName: rootElementName))
        let options = _XMLEncoderOptions(configuration: configuration)
        let encoder = _XMLTreeEncoder(
            options: options,
            codingPath: [],
            node: rootNode,
            fieldNodeKinds: _xmlFieldNodeKinds(for: T.self)
        )
        try value.encode(to: encoder)
        return XMLTreeDocument(root: rootNode.makeElement())
    }

    private func resolveRootElementName<T>(for type: T.Type) throws -> String {
        if let explicitName = XMLRootNameResolver.explicitRootElementName(from: configuration.rootElementName) {
            return explicitName
        }

        if let implicitName = try XMLRootNameResolver.implicitRootElementName(for: type) {
            return implicitName
        }

        return XMLRootNameResolver.fallbackRootElementName(for: type)
    }
}
