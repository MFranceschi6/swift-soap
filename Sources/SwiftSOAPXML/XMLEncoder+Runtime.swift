import Foundation

struct _XMLEncoderOptions {
    let itemElementName: String
    let fieldCodingOverrides: XMLFieldCodingOverrides
    let nilEncodingStrategy: XMLEncoder.NilEncodingStrategy
    let dateEncodingStrategy: XMLEncoder.DateEncodingStrategy
    let dataEncodingStrategy: XMLEncoder.DataEncodingStrategy

    init(configuration: XMLEncoder.Configuration) {
        self.itemElementName = configuration.itemElementName
        self.fieldCodingOverrides = configuration.fieldCodingOverrides
        self.nilEncodingStrategy = configuration.nilEncodingStrategy
        self.dateEncodingStrategy = configuration.dateEncodingStrategy
        self.dataEncodingStrategy = configuration.dataEncodingStrategy
    }
}

enum _XMLTreeContentBox {
    case text(String)
    case element(_XMLTreeElementBox)
}

final class _XMLTreeElementBox {
    let name: XMLQualifiedName
    var attributes: [XMLTreeAttribute]
    var namespaceDeclarations: [XMLNamespaceDeclaration]
    private var contents: [_XMLTreeContentBox]

    init(
        name: XMLQualifiedName,
        attributes: [XMLTreeAttribute] = [],
        namespaceDeclarations: [XMLNamespaceDeclaration] = []
    ) {
        self.name = name
        self.attributes = attributes
        self.namespaceDeclarations = namespaceDeclarations
        self.contents = []
    }

    func appendText(_ value: String) {
        contents.append(.text(value))
    }

    func appendElement(_ child: _XMLTreeElementBox) {
        contents.append(.element(child))
    }

    @discardableResult
    func makeChild(localName: String) -> _XMLTreeElementBox {
        let child = _XMLTreeElementBox(name: XMLQualifiedName(localName: localName))
        appendElement(child)
        return child
    }

    func makeElement() -> XMLTreeElement {
        let children = contents.map { content in
            switch content {
            case .text(let value):
                return XMLTreeNode.text(value)
            case .element(let child):
                return XMLTreeNode.element(child.makeElement())
            }
        }

        return XMLTreeElement(
            name: name,
            attributes: attributes,
            namespaceDeclarations: namespaceDeclarations,
            children: children
        )
    }
}

struct _XMLEncodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "Index\(intValue)"
        self.intValue = intValue
    }

    init(index: Int) {
        self.stringValue = "Index\(index)"
        self.intValue = index
    }
}

final class _XMLTreeEncoder: Encoder {
    let options: _XMLEncoderOptions
    let node: _XMLTreeElementBox
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    init(options: _XMLEncoderOptions, codingPath: [CodingKey], node: _XMLTreeElementBox) {
        self.options = options
        self.codingPath = codingPath
        self.node = node
    }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        let container = _XMLKeyedEncodingContainer<Key>(encoder: self, codingPath: codingPath)
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        _XMLUnkeyedEncodingContainer(encoder: self, codingPath: codingPath)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        _XMLSingleValueEncodingContainer(encoder: self, codingPath: codingPath)
    }

    func boxedScalar<T: Encodable>(
        _ value: T,
        codingPath: [CodingKey],
        localName: String?,
        isAttribute: Bool = false
    ) throws -> String? {
        switch value {
        case let string as String:
            return string
        case let bool as Bool:
            return bool ? "true" : "false"
        case let int as Int:
            return String(int)
        case let int8 as Int8:
            return String(int8)
        case let int16 as Int16:
            return String(int16)
        case let int32 as Int32:
            return String(int32)
        case let int64 as Int64:
            return String(int64)
        case let uint as UInt:
            return String(uint)
        case let uint8 as UInt8:
            return String(uint8)
        case let uint16 as UInt16:
            return String(uint16)
        case let uint32 as UInt32:
            return String(uint32)
        case let uint64 as UInt64:
            return String(uint64)
        case let float as Float:
            return String(float)
        case let double as Double:
            return String(double)
        case let decimal as Decimal:
            return NSDecimalNumber(decimal: decimal).stringValue
        case let url as URL:
            return url.absoluteString
        case let uuid as UUID:
            return uuid.uuidString
        case let date as Date:
            return try boxedDate(date, codingPath: codingPath, localName: localName, isAttribute: isAttribute)
        case let data as Data:
            return boxedData(data)
        default:
            return nil
        }
    }

    private func boxedDate(
        _ date: Date,
        codingPath: [CodingKey],
        localName: String?,
        isAttribute: Bool
    ) throws -> String? {
        let context = XMLDateCodingContext(
            codingPath: codingPath.map(\.stringValue),
            localName: localName,
            namespaceURI: nil,
            isAttribute: isAttribute
        )

        switch options.dateEncodingStrategy {
        case .deferredToDate:
            return nil
        case .secondsSince1970:
            return String(date.timeIntervalSince1970)
        case .millisecondsSince1970:
            return String(date.timeIntervalSince1970 * 1000.0)
        case .xsdDateTimeISO8601:
            return _XMLTemporalFoundationSupport.formatISO8601(date)
        case .iso8601:
            return _XMLTemporalFoundationSupport.formatISO8601(date)
        case .formatter(let descriptor):
            return _XMLTemporalFoundationSupport.makeDateFormatter(from: descriptor).string(from: date)
        case .custom(let closure):
            do {
                return try closure(date, context)
            } catch let error as XMLParsingError {
                throw error
            } catch {
                throw XMLParsingError.parseFailed(
                    message: "[XML6_5C_DATE_ENCODE_CUSTOM_FAILED] Custom date encoder failed at path '\(context.codingPath.joined(separator: "."))': \(error)."
                )
            }
        }
    }

    private func boxedData(_ data: Data) -> String? {
        switch options.dataEncodingStrategy {
        case .deferredToData:
            return nil
        case .base64:
            return data.base64EncodedString()
        case .hex:
            return data.map { String(format: "%02x", $0) }.joined()
        }
    }

    func addNilElementIfNeeded(localName: String) {
        if options.nilEncodingStrategy == .emptyElement {
            _ = node.makeChild(localName: localName)
        }
    }
}

struct _XMLKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    typealias Key = Key

    private let encoder: _XMLTreeEncoder
    private(set) var codingPath: [CodingKey]

    init(encoder: _XMLTreeEncoder, codingPath: [CodingKey]) {
        self.encoder = encoder
        self.codingPath = codingPath
    }

    mutating func encodeNil(forKey key: Key) throws {
        if resolvedNodeKind(for: key, valueType: Never.self) == .attribute {
            return
        }
        encoder.addNilElementIfNeeded(localName: key.stringValue)
    }

    mutating func encode(_ value: Bool, forKey key: Key) throws { try encodeEncodable(value, forKey: key) }
    mutating func encode(_ value: String, forKey key: Key) throws { try encodeEncodable(value, forKey: key) }
    mutating func encode(_ value: Double, forKey key: Key) throws { try encodeEncodable(value, forKey: key) }
    mutating func encode(_ value: Float, forKey key: Key) throws { try encodeEncodable(value, forKey: key) }
    mutating func encode(_ value: Int, forKey key: Key) throws { try encodeEncodable(value, forKey: key) }
    mutating func encode(_ value: Int8, forKey key: Key) throws { try encodeEncodable(value, forKey: key) }
    mutating func encode(_ value: Int16, forKey key: Key) throws { try encodeEncodable(value, forKey: key) }
    mutating func encode(_ value: Int32, forKey key: Key) throws { try encodeEncodable(value, forKey: key) }
    mutating func encode(_ value: Int64, forKey key: Key) throws { try encodeEncodable(value, forKey: key) }
    mutating func encode(_ value: UInt, forKey key: Key) throws { try encodeEncodable(value, forKey: key) }
    mutating func encode(_ value: UInt8, forKey key: Key) throws { try encodeEncodable(value, forKey: key) }
    mutating func encode(_ value: UInt16, forKey key: Key) throws { try encodeEncodable(value, forKey: key) }
    mutating func encode(_ value: UInt32, forKey key: Key) throws { try encodeEncodable(value, forKey: key) }
    mutating func encode(_ value: UInt64, forKey key: Key) throws { try encodeEncodable(value, forKey: key) }

    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        try encodeEncodable(value, forKey: key)
    }

    private mutating func encodeEncodable<T: Encodable>(_ value: T, forKey key: Key) throws {
        let nodeKind = resolvedNodeKind(for: key, valueType: T.self)
        if nodeKind == .attribute {
            try encodeAttribute(value, forKey: key)
            return
        }

        if let scalar = try encoder.boxedScalar(
            value,
            codingPath: codingPath + [key],
            localName: key.stringValue
        ) {
            try encodeScalarString(scalar, forKey: key)
            return
        }

        let child = encoder.node.makeChild(localName: key.stringValue)
        let nestedEncoder = _XMLTreeEncoder(
            options: encoder.options,
            codingPath: codingPath + [key],
            node: child
        )
        try value.encode(to: nestedEncoder)
    }

    mutating func nestedContainer<NestedKey>(
        keyedBy keyType: NestedKey.Type,
        forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        let child = encoder.node.makeChild(localName: key.stringValue)
        let nestedEncoder = _XMLTreeEncoder(
            options: encoder.options,
            codingPath: codingPath + [key],
            node: child
        )
        return nestedEncoder.container(keyedBy: keyType)
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let child = encoder.node.makeChild(localName: key.stringValue)
        let nestedEncoder = _XMLTreeEncoder(
            options: encoder.options,
            codingPath: codingPath + [key],
            node: child
        )
        return nestedEncoder.unkeyedContainer()
    }

    mutating func superEncoder() -> Encoder {
        let superKey = _XMLEncodingKey(stringValue: "super") ?? _XMLEncodingKey(index: 0)
        let child = encoder.node.makeChild(localName: superKey.stringValue)
        return _XMLTreeEncoder(
            options: encoder.options,
            codingPath: codingPath + [superKey],
            node: child
        )
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        let child = encoder.node.makeChild(localName: key.stringValue)
        return _XMLTreeEncoder(
            options: encoder.options,
            codingPath: codingPath + [key],
            node: child
        )
    }

    private func encodeScalarString(_ value: String, forKey key: Key) throws {
        let child = encoder.node.makeChild(localName: key.stringValue)
        child.appendText(value)
    }

    private mutating func encodeAttribute<T: Encodable>(_ value: T, forKey key: Key) throws {
        let lexicalValue: String
        if let provider = value as? _XMLAttributeEncodableValue {
            lexicalValue = try provider._xmlAttributeLexicalValue(
                using: encoder,
                codingPath: codingPath + [key],
                key: key.stringValue
            )
        } else if let scalar = try encoder.boxedScalar(
            value,
            codingPath: codingPath + [key],
            localName: key.stringValue,
            isAttribute: true
        ) {
            lexicalValue = scalar
        } else {
            throw XMLParsingError.parseFailed(
                message: "[XML6_6_ATTRIBUTE_ENCODE_UNSUPPORTED] Key '\(key.stringValue)' cannot be encoded as XML attribute because value is not scalar."
            )
        }

        encoder.node.attributes.append(
            XMLTreeAttribute(
                name: XMLQualifiedName(localName: key.stringValue),
                value: lexicalValue
            )
        )
    }

    private func resolvedNodeKind<T>(for key: Key, valueType: T.Type) -> XMLFieldNodeKind {
        if let typeOverride = valueType as? _XMLFieldKindOverrideType.Type {
            return typeOverride._xmlFieldNodeKindOverride
        }

        if let override = encoder.options.fieldCodingOverrides.nodeKind(for: codingPath, key: key.stringValue) {
            return override
        }

        return .element
    }
}

struct _XMLUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    private let encoder: _XMLTreeEncoder
    private(set) var codingPath: [CodingKey]
    private(set) var count: Int = 0

    init(encoder: _XMLTreeEncoder, codingPath: [CodingKey]) {
        self.encoder = encoder
        self.codingPath = codingPath
    }

    mutating func encodeNil() throws {
        guard encoder.options.nilEncodingStrategy == .emptyElement else {
            return
        }

        _ = makeItemNode()
    }

    mutating func encode(_ value: Bool) throws { try encodeScalar(value) }
    mutating func encode(_ value: String) throws { try encodeScalar(value) }
    mutating func encode(_ value: Double) throws { try encodeScalar(value) }
    mutating func encode(_ value: Float) throws { try encodeScalar(value) }
    mutating func encode(_ value: Int) throws { try encodeScalar(value) }
    mutating func encode(_ value: Int8) throws { try encodeScalar(value) }
    mutating func encode(_ value: Int16) throws { try encodeScalar(value) }
    mutating func encode(_ value: Int32) throws { try encodeScalar(value) }
    mutating func encode(_ value: Int64) throws { try encodeScalar(value) }
    mutating func encode(_ value: UInt) throws { try encodeScalar(value) }
    mutating func encode(_ value: UInt8) throws { try encodeScalar(value) }
    mutating func encode(_ value: UInt16) throws { try encodeScalar(value) }
    mutating func encode(_ value: UInt32) throws { try encodeScalar(value) }
    mutating func encode(_ value: UInt64) throws { try encodeScalar(value) }

    mutating func encode<T: Encodable>(_ value: T) throws {
        let indexKey = _XMLEncodingKey(index: count)
        if let scalar = try encoder.boxedScalar(
            value,
            codingPath: codingPath + [indexKey],
            localName: encoder.options.itemElementName
        ) {
            let itemNode = makeItemNode()
            itemNode.appendText(scalar)
            return
        }

        let itemNode = makeItemNode()
        let currentIndexKey = _XMLEncodingKey(index: count - 1)
        let nestedEncoder = _XMLTreeEncoder(
            options: encoder.options,
            codingPath: codingPath + [currentIndexKey],
            node: itemNode
        )
        try value.encode(to: nestedEncoder)
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey>
    where NestedKey: CodingKey {
        let itemNode = makeItemNode()
        let indexKey = _XMLEncodingKey(index: count - 1)
        let nestedEncoder = _XMLTreeEncoder(
            options: encoder.options,
            codingPath: codingPath + [indexKey],
            node: itemNode
        )
        return nestedEncoder.container(keyedBy: keyType)
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let itemNode = makeItemNode()
        let indexKey = _XMLEncodingKey(index: count - 1)
        let nestedEncoder = _XMLTreeEncoder(
            options: encoder.options,
            codingPath: codingPath + [indexKey],
            node: itemNode
        )
        return nestedEncoder.unkeyedContainer()
    }

    mutating func superEncoder() -> Encoder {
        let itemNode = makeItemNode()
        let indexKey = _XMLEncodingKey(index: count - 1)
        return _XMLTreeEncoder(
            options: encoder.options,
            codingPath: codingPath + [indexKey],
            node: itemNode
        )
    }

    private mutating func encodeScalar<T: Encodable>(_ value: T) throws {
        let indexKey = _XMLEncodingKey(index: count)
        guard let scalar = try encoder.boxedScalar(
            value,
            codingPath: codingPath + [indexKey],
            localName: encoder.options.itemElementName
        ) else {
            throw XMLParsingError.parseFailed(
                message: "[XML6_4_UNKEYED_SCALAR] Unable to box unkeyed scalar."
            )
        }
        let itemNode = makeItemNode()
        itemNode.appendText(scalar)
    }

    private mutating func makeItemNode() -> _XMLTreeElementBox {
        count += 1
        return encoder.node.makeChild(localName: encoder.options.itemElementName)
    }
}

struct _XMLSingleValueEncodingContainer: SingleValueEncodingContainer {
    private let encoder: _XMLTreeEncoder
    private(set) var codingPath: [CodingKey]

    init(encoder: _XMLTreeEncoder, codingPath: [CodingKey]) {
        self.encoder = encoder
        self.codingPath = codingPath
    }

    mutating func encodeNil() throws {
        if encoder.options.nilEncodingStrategy == .emptyElement {
            // Empty root element: no-op.
        }
    }

    mutating func encode(_ value: Bool) throws { try encodeScalar(value) }
    mutating func encode(_ value: String) throws { try encodeScalar(value) }
    mutating func encode(_ value: Double) throws { try encodeScalar(value) }
    mutating func encode(_ value: Float) throws { try encodeScalar(value) }
    mutating func encode(_ value: Int) throws { try encodeScalar(value) }
    mutating func encode(_ value: Int8) throws { try encodeScalar(value) }
    mutating func encode(_ value: Int16) throws { try encodeScalar(value) }
    mutating func encode(_ value: Int32) throws { try encodeScalar(value) }
    mutating func encode(_ value: Int64) throws { try encodeScalar(value) }
    mutating func encode(_ value: UInt) throws { try encodeScalar(value) }
    mutating func encode(_ value: UInt8) throws { try encodeScalar(value) }
    mutating func encode(_ value: UInt16) throws { try encodeScalar(value) }
    mutating func encode(_ value: UInt32) throws { try encodeScalar(value) }
    mutating func encode(_ value: UInt64) throws { try encodeScalar(value) }

    mutating func encode<T: Encodable>(_ value: T) throws {
        if let scalar = try encoder.boxedScalar(
            value,
            codingPath: codingPath,
            localName: encoder.node.name.localName
        ) {
            encoder.node.appendText(scalar)
            return
        }
        try value.encode(to: encoder)
    }

    private mutating func encodeScalar<T: Encodable>(_ value: T) throws {
        guard let scalar = try encoder.boxedScalar(
            value,
            codingPath: codingPath,
            localName: encoder.node.name.localName
        ) else {
            throw XMLParsingError.parseFailed(
                message: "[XML6_4_SINGLE_SCALAR] Unable to box single value scalar."
            )
        }
        encoder.node.appendText(scalar)
    }
}
