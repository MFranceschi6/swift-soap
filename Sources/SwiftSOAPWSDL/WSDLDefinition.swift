public struct WSDLDefinition: Sendable, Equatable {
    public let name: String?
    public let targetNamespace: String?
    public let types: Types
    public let messages: [Message]
    public let portTypes: [PortType]
    public let bindings: [Binding]
    public let services: [Service]

    public init(
        name: String?,
        targetNamespace: String?,
        types: Types = Types(schemas: []),
        messages: [Message],
        portTypes: [PortType],
        bindings: [Binding],
        services: [Service]
    ) {
        self.name = name
        self.targetNamespace = targetNamespace
        self.types = types
        self.messages = messages
        self.portTypes = portTypes
        self.bindings = bindings
        self.services = services
    }
}

extension WSDLDefinition {
    public struct QName: Sendable, Equatable, Codable {
        public let rawValue: String
        public let prefix: String?
        public let localName: String
        public let namespaceURI: String?

        public init(rawValue: String, prefix: String?, localName: String, namespaceURI: String?) {
            self.rawValue = rawValue
            self.prefix = prefix
            self.localName = localName
            self.namespaceURI = namespaceURI
        }
    }

    public enum SOAPEnvelopeVersion: String, Sendable, Equatable, Codable {
        case soap11
        case soap12
    }

    public enum SOAPBindingStyle: String, Sendable, Equatable, Codable {
        case document
        case rpc
    }

    public enum SOAPBodyUse: String, Sendable, Equatable, Codable {
        case literal
        case encoded
    }

    public struct Message: Sendable, Equatable {
        public let name: String
        public let parts: [Part]

        public init(name: String, parts: [Part]) {
            self.name = name
            self.parts = parts
        }
    }

    public struct Part: Sendable, Equatable {
        public let name: String
        public let elementName: String?
        public let typeName: String?
        public let elementQName: QName?
        public let typeQName: QName?

        public init(
            name: String,
            elementName: String?,
            typeName: String?,
            elementQName: QName? = nil,
            typeQName: QName? = nil
        ) {
            self.name = name
            self.elementName = elementName ?? elementQName?.localName
            self.typeName = typeName ?? typeQName?.localName
            self.elementQName = elementQName
            self.typeQName = typeQName
        }
    }

    public struct PortType: Sendable, Equatable {
        public let name: String
        public let operations: [Operation]

        public init(name: String, operations: [Operation]) {
            self.name = name
            self.operations = operations
        }
    }

    public struct Operation: Sendable, Equatable {
        public let name: String
        public let inputMessageName: String?
        public let outputMessageName: String?
        public let inputMessageQName: QName?
        public let outputMessageQName: QName?
        public let faults: [Fault]

        public init(
            name: String,
            inputMessageName: String?,
            outputMessageName: String?,
            inputMessageQName: QName? = nil,
            outputMessageQName: QName? = nil,
            faults: [Fault]
        ) {
            self.name = name
            self.inputMessageName = inputMessageName ?? inputMessageQName?.localName
            self.outputMessageName = outputMessageName ?? outputMessageQName?.localName
            self.inputMessageQName = inputMessageQName
            self.outputMessageQName = outputMessageQName
            self.faults = faults
        }
    }

    public struct Fault: Sendable, Equatable {
        public let name: String
        public let messageName: String?
        public let messageQName: QName?

        public init(name: String, messageName: String?, messageQName: QName? = nil) {
            self.name = name
            self.messageName = messageName ?? messageQName?.localName
            self.messageQName = messageQName
        }
    }

    public struct Binding: Sendable, Equatable {
        public let name: String
        public let typeName: String?
        public let typeQName: QName?
        public let soapVersion: SOAPEnvelopeVersion?
        public let style: String?
        public let styleKind: SOAPBindingStyle?
        public let operations: [BindingOperation]

        public init(
            name: String,
            typeName: String?,
            style: String?,
            operations: [BindingOperation],
            typeQName: QName? = nil,
            soapVersion: SOAPEnvelopeVersion? = nil,
            styleKind: SOAPBindingStyle? = nil
        ) {
            self.name = name
            self.typeName = typeName ?? typeQName?.localName
            self.typeQName = typeQName
            self.soapVersion = soapVersion
            self.style = style ?? styleKind?.rawValue
            self.styleKind = styleKind
            self.operations = operations
        }
    }

    public struct BindingOperation: Sendable, Equatable {
        public let name: String
        public let soapAction: String?
        public let style: String?
        public let styleKind: SOAPBindingStyle?
        public let inputUse: String?
        public let inputUseKind: SOAPBodyUse?
        public let outputUse: String?
        public let outputUseKind: SOAPBodyUse?

        public init(
            name: String,
            soapAction: String?,
            style: String? = nil,
            inputUse: String? = nil,
            outputUse: String? = nil,
            styleKind: SOAPBindingStyle? = nil,
            inputUseKind: SOAPBodyUse? = nil,
            outputUseKind: SOAPBodyUse? = nil
        ) {
            self.name = name
            self.soapAction = soapAction
            self.style = style ?? styleKind?.rawValue
            self.styleKind = styleKind
            self.inputUse = inputUse ?? inputUseKind?.rawValue
            self.inputUseKind = inputUseKind
            self.outputUse = outputUse ?? outputUseKind?.rawValue
            self.outputUseKind = outputUseKind
        }
    }

    public struct Service: Sendable, Equatable {
        public let name: String
        public let ports: [ServicePort]

        public init(name: String, ports: [ServicePort]) {
            self.name = name
            self.ports = ports
        }
    }

    public struct ServicePort: Sendable, Equatable {
        public let name: String
        public let bindingName: String?
        public let bindingQName: QName?
        public let address: String?

        public init(name: String, bindingName: String?, address: String?, bindingQName: QName? = nil) {
            self.name = name
            self.bindingName = bindingName ?? bindingQName?.localName
            self.bindingQName = bindingQName
            self.address = address
        }
    }

    public struct Types: Sendable, Equatable {
        public let schemas: [Schema]

        public init(schemas: [Schema]) {
            self.schemas = schemas
        }
    }

    public struct Schema: Sendable, Equatable {
        public let targetNamespace: String?
        public let imports: [SchemaImport]
        public let includes: [SchemaInclude]
        public let elements: [Element]
        public let complexTypes: [ComplexType]
        public let simpleTypes: [SimpleType]

        public init(
            targetNamespace: String?,
            imports: [SchemaImport],
            includes: [SchemaInclude],
            elements: [Element],
            complexTypes: [ComplexType],
            simpleTypes: [SimpleType]
        ) {
            self.targetNamespace = targetNamespace
            self.imports = imports
            self.includes = includes
            self.elements = elements
            self.complexTypes = complexTypes
            self.simpleTypes = simpleTypes
        }
    }

    public struct SchemaImport: Sendable, Equatable {
        public let namespace: String?
        public let schemaLocation: String?

        public init(namespace: String?, schemaLocation: String?) {
            self.namespace = namespace
            self.schemaLocation = schemaLocation
        }
    }

    public struct SchemaInclude: Sendable, Equatable {
        public let schemaLocation: String

        public init(schemaLocation: String) {
            self.schemaLocation = schemaLocation
        }
    }

    public struct Element: Sendable, Equatable {
        public let name: String
        public let typeQName: QName?
        public let refQName: QName?
        public let minOccurs: Int?
        public let maxOccurs: String?
        public let nillable: Bool

        public init(
            name: String,
            typeQName: QName?,
            refQName: QName?,
            minOccurs: Int?,
            maxOccurs: String?,
            nillable: Bool
        ) {
            self.name = name
            self.typeQName = typeQName
            self.refQName = refQName
            self.minOccurs = minOccurs
            self.maxOccurs = maxOccurs
            self.nillable = nillable
        }
    }

    public struct ComplexType: Sendable, Equatable {
        public let name: String
        public let sequence: [Element]
        public let choice: [Element]
        public let attributes: [Attribute]

        public init(name: String, sequence: [Element], choice: [Element], attributes: [Attribute]) {
            self.name = name
            self.sequence = sequence
            self.choice = choice
            self.attributes = attributes
        }
    }

    public struct Facets: Sendable, Equatable {
        public let enumeration: [String]
        public let pattern: String?
        public let minLength: Int?
        public let maxLength: Int?
        public let length: Int?
        public let minInclusive: String?
        public let maxInclusive: String?
        public let totalDigits: Int?
        public let fractionDigits: Int?

        public init(
            enumeration: [String] = [],
            pattern: String? = nil,
            minLength: Int? = nil,
            maxLength: Int? = nil,
            length: Int? = nil,
            minInclusive: String? = nil,
            maxInclusive: String? = nil,
            totalDigits: Int? = nil,
            fractionDigits: Int? = nil
        ) {
            self.enumeration = enumeration
            self.pattern = pattern
            self.minLength = minLength
            self.maxLength = maxLength
            self.length = length
            self.minInclusive = minInclusive
            self.maxInclusive = maxInclusive
            self.totalDigits = totalDigits
            self.fractionDigits = fractionDigits
        }

        public var isEmpty: Bool {
            enumeration.isEmpty && pattern == nil && minLength == nil &&
            maxLength == nil && length == nil && minInclusive == nil &&
            maxInclusive == nil && totalDigits == nil && fractionDigits == nil
        }
    }

    public struct SimpleType: Sendable, Equatable {
        public let name: String
        public let baseQName: QName?
        public let enumerationValues: [String]
        public let pattern: String?
        public let facets: Facets?

        public init(
            name: String,
            baseQName: QName?,
            enumerationValues: [String],
            pattern: String?,
            facets: Facets? = nil
        ) {
            self.name = name
            self.baseQName = baseQName
            self.enumerationValues = enumerationValues
            self.pattern = pattern
            self.facets = facets
        }
    }

    public struct Attribute: Sendable, Equatable {
        public let name: String
        public let typeQName: QName?
        public let use: String?

        public init(name: String, typeQName: QName?, use: String?) {
            self.name = name
            self.typeQName = typeQName
            self.use = use
        }
    }
}
