import Foundation

public enum XMLFieldNodeKind: String, Sendable, Hashable, Codable {
    case element
    case attribute
}

public struct XMLFieldCodingOverrides: Sendable, Hashable, Codable {
    public let mapping: [String: XMLFieldNodeKind]

    public init(mapping: [String: XMLFieldNodeKind] = [:]) {
        self.mapping = mapping
    }

    public func setting(path: [String], key: String, as nodeKind: XMLFieldNodeKind) -> XMLFieldCodingOverrides {
        var updated = mapping
        updated[Self.lookupKey(path: path, key: key)] = nodeKind
        return XMLFieldCodingOverrides(mapping: updated)
    }

    public func nodeKind(for path: [String], key: String) -> XMLFieldNodeKind? {
        mapping[Self.lookupKey(path: path, key: key)]
    }

    func nodeKind(for codingPath: [CodingKey], key: String) -> XMLFieldNodeKind? {
        nodeKind(for: codingPath.map(\.stringValue), key: key)
    }

    public static func lookupKey(path: [String], key: String) -> String {
        (path + [key]).joined(separator: ".")
    }
}

public protocol XMLFieldCodingOverrideProvider {
    static var xmlFieldNodeKinds: [String: XMLFieldNodeKind] { get }
}

public extension XMLFieldCodingOverrideProvider {
    static var xmlFieldNodeKinds: [String: XMLFieldNodeKind] { [:] }
}

protocol _XMLFieldKindOverrideType {
    static var _xmlFieldNodeKindOverride: XMLFieldNodeKind { get }
}

protocol _XMLAttributeEncodableValue {
    func _xmlAttributeLexicalValue(
        using encoder: _XMLTreeEncoder,
        codingPath: [CodingKey],
        key: String
    ) throws -> String
}

protocol _XMLAttributeDecodableValue {
    static func _xmlDecodeAttributeLexicalValue(
        _ lexicalValue: String,
        using decoder: _XMLTreeDecoder,
        codingPath: [CodingKey],
        key: String
    ) throws -> Self
}

@propertyWrapper
public struct XMLAttribute<Value: Codable>: Codable {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        self.wrappedValue = try Value(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension XMLAttribute: Equatable where Value: Equatable {}
extension XMLAttribute: Hashable where Value: Hashable {}

extension XMLAttribute: _XMLFieldKindOverrideType {
    static var _xmlFieldNodeKindOverride: XMLFieldNodeKind { .attribute }
}

extension XMLAttribute: _XMLAttributeEncodableValue {
    func _xmlAttributeLexicalValue(
        using encoder: _XMLTreeEncoder,
        codingPath: [CodingKey],
        key: String
    ) throws -> String {
        guard let lexical = try encoder.boxedScalar(
            wrappedValue,
            codingPath: codingPath,
            localName: key,
            isAttribute: true
        ) else {
            throw XMLParsingError.parseFailed(
                message: "[XML6_6_ATTRIBUTE_ENCODE_UNSUPPORTED] Unable to encode attribute '\(key)' from non-scalar value."
            )
        }
        return lexical
    }
}

extension XMLAttribute: _XMLAttributeDecodableValue {
    static func _xmlDecodeAttributeLexicalValue(
        _ lexicalValue: String,
        using decoder: _XMLTreeDecoder,
        codingPath: [CodingKey],
        key: String
    ) throws -> XMLAttribute<Value> {
        guard let value = try decoder.decodeScalarFromLexical(
            lexicalValue,
            as: Value.self,
            codingPath: codingPath,
            localName: key,
            isAttribute: true
        ) else {
            throw XMLParsingError.parseFailed(
                message: "[XML6_6_ATTRIBUTE_DECODE_UNSUPPORTED] Unable to decode attribute '\(key)' into target value type."
            )
        }
        return XMLAttribute(wrappedValue: value)
    }
}

@propertyWrapper
public struct XMLElement<Value: Codable>: Codable {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        self.wrappedValue = try Value(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension XMLElement: Equatable where Value: Equatable {}
extension XMLElement: Hashable where Value: Hashable {}

extension XMLElement: _XMLFieldKindOverrideType {
    static var _xmlFieldNodeKindOverride: XMLFieldNodeKind { .element }
}
