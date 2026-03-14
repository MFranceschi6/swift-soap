import Foundation
import SwiftSOAPWSDL

public struct SOAPCodeGenerationIR: Sendable, Equatable {
    public let moduleName: String
    public let generationScope: Set<CodeGenerationScopeOption>
    public let runtimeTargets: Set<CodeGenerationRuntimeTargetOption>
    public let generatedProtocols: [GeneratedProtocolIR]
    public let generatedTypes: [GeneratedTypeIR]
    public let services: [ServiceIR]
    public let validationProfile: ValidationProfile

    public init(
        moduleName: String,
        generationScope: Set<CodeGenerationScopeOption>,
        runtimeTargets: Set<CodeGenerationRuntimeTargetOption>,
        generatedProtocols: [GeneratedProtocolIR] = [],
        generatedTypes: [GeneratedTypeIR],
        services: [ServiceIR],
        validationProfile: ValidationProfile = .strict
    ) {
        self.moduleName = moduleName
        self.generationScope = generationScope
        self.runtimeTargets = runtimeTargets
        self.generatedProtocols = generatedProtocols
        self.generatedTypes = generatedTypes
        self.services = services
        self.validationProfile = validationProfile
    }
}

public enum GeneratedTypeKind: String, Sendable, Equatable {
    case bodyPayload
    case faultDetailPayload
    case schemaModel
    /// XSD simpleType with enumeration facet — emitted as a Swift `enum : String`.
    case enumeration
}

public enum FacetConstraintKind: String, Sendable, Equatable {
    case minLength
    case maxLength
    case length
    case pattern
    case minInclusive
    case maxInclusive
    case minExclusive
    case maxExclusive
    case totalDigits
    case fractionDigits
}

public struct FacetConstraintIR: Sendable, Equatable {
    public let kind: FacetConstraintKind
    public let value: String

    public init(kind: FacetConstraintKind, value: String) {
        self.kind = kind
        self.value = value
    }
}

public enum GeneratedXMLFieldKindIR: String, Sendable, Equatable {
    case element
    case attribute
    case text
}

public struct GeneratedTypeFieldIR: Sendable, Equatable {
    public let name: String
    public let swiftTypeName: String
    public let isOptional: Bool
    public let xmlFieldKind: GeneratedXMLFieldKindIR
    /// Lower XSD occurrence bound for repeated fields represented as Swift arrays.
    public let minOccurs: Int?
    /// Upper XSD occurrence bound for repeated fields represented as Swift arrays.
    /// Nil means either "not repeated" or an unbounded array.
    public let maxOccurs: Int?
    /// XML element/attribute name when it differs from the sanitized Swift name; nil = same as name.
    public let xmlName: String?
    /// Position in the XSD sequence; nil = unspecified.
    public let xmlOrder: Int?
    /// XSD facet constraints for non-enumeration validation.
    public let constraints: [FacetConstraintIR]

    public init(
        name: String,
        swiftTypeName: String,
        isOptional: Bool,
        xmlFieldKind: GeneratedXMLFieldKindIR = .element,
        minOccurs: Int? = nil,
        maxOccurs: Int? = nil,
        xmlName: String? = nil,
        xmlOrder: Int? = nil,
        constraints: [FacetConstraintIR] = []
    ) {
        self.name = name
        self.swiftTypeName = swiftTypeName
        self.isOptional = isOptional
        self.xmlFieldKind = xmlFieldKind
        self.minOccurs = minOccurs
        self.maxOccurs = maxOccurs
        self.xmlName = xmlName
        self.xmlOrder = xmlOrder
        self.constraints = constraints
    }
}

public struct GeneratedProtocolIR: Sendable, Equatable {
    public let swiftTypeName: String
    public let inheritedProtocolNames: [String]
    public let fields: [GeneratedTypeFieldIR]

    public init(
        swiftTypeName: String,
        inheritedProtocolNames: [String] = [],
        fields: [GeneratedTypeFieldIR]
    ) {
        self.swiftTypeName = swiftTypeName
        self.inheritedProtocolNames = inheritedProtocolNames
        self.fields = fields
    }
}

public struct GeneratedChoiceGroupIR: Sendable, Equatable {
    public let fieldNames: [String]
    /// Lower bound for how many branch selections the choice group requires.
    public let minOccurs: Int
    /// Upper bound for branch selections. Nil means unbounded.
    public let maxOccurs: Int?

    public init(fieldNames: [String], minOccurs: Int = 1, maxOccurs: Int? = 1) {
        self.fieldNames = fieldNames
        self.minOccurs = minOccurs
        self.maxOccurs = maxOccurs
    }
}

public struct GeneratedTypeIR: Sendable, Equatable {
    public let swiftTypeName: String
    public let kind: GeneratedTypeKind
    public let protocolConformances: [String]
    public let fields: [GeneratedTypeFieldIR]
    public let choiceGroups: [GeneratedChoiceGroupIR]
    /// Populated only for `kind == .enumeration`; raw string values of each enum case.
    public let enumerationCases: [String]
    /// XML root element name for doc/literal element-reference payloads.
    /// When non-nil the emitter generates an `XMLRootNode` conformance with this name,
    /// overriding the default (Swift type name) used by the XML encoder.
    public let xmlRootElementName: String?
    /// XML namespace URI for the root element (e.g. the schema's `targetNamespace`).
    /// When non-nil the emitter emits `xmlRootElementNamespaceURI` on the `XMLRootNode` conformance.
    public let xmlRootElementNamespaceURI: String?

    public init(
        swiftTypeName: String,
        kind: GeneratedTypeKind,
        protocolConformances: [String] = [],
        fields: [GeneratedTypeFieldIR],
        choiceGroups: [GeneratedChoiceGroupIR] = [],
        enumerationCases: [String] = [],
        xmlRootElementName: String? = nil,
        xmlRootElementNamespaceURI: String? = nil
    ) {
        self.swiftTypeName = swiftTypeName
        self.kind = kind
        self.protocolConformances = protocolConformances
        self.fields = fields
        self.choiceGroups = choiceGroups
        self.enumerationCases = enumerationCases
        self.xmlRootElementName = xmlRootElementName
        self.xmlRootElementNamespaceURI = xmlRootElementNamespaceURI
    }
}

public struct ServiceIR: Sendable, Equatable {
    public let swiftTypeName: String
    public let ports: [ServicePortIR]

    public init(swiftTypeName: String, ports: [ServicePortIR]) {
        self.swiftTypeName = swiftTypeName
        self.ports = ports
    }
}

public struct ServicePortIR: Sendable, Equatable {
    public let swiftTypeName: String
    public let operations: [OperationIR]

    public init(swiftTypeName: String, operations: [OperationIR]) {
        self.swiftTypeName = swiftTypeName
        self.operations = operations
    }
}

public struct OperationIR: Sendable, Equatable {
    public let swiftMethodName: String
    public let operationContractTypeName: String
    public let operationIdentifierRawValue: String
    public let requestPayloadTypeName: String
    public let responsePayloadTypeName: String
    public let faultDetailTypeName: String
    public let soapAction: String?
    public let bindingMetadata: BindingMetadataIR

    public init(
        swiftMethodName: String,
        operationContractTypeName: String,
        operationIdentifierRawValue: String,
        requestPayloadTypeName: String,
        responsePayloadTypeName: String,
        faultDetailTypeName: String,
        soapAction: String?,
        bindingMetadata: BindingMetadataIR
    ) {
        self.swiftMethodName = swiftMethodName
        self.operationContractTypeName = operationContractTypeName
        self.operationIdentifierRawValue = operationIdentifierRawValue
        self.requestPayloadTypeName = requestPayloadTypeName
        self.responsePayloadTypeName = responsePayloadTypeName
        self.faultDetailTypeName = faultDetailTypeName
        self.soapAction = soapAction
        self.bindingMetadata = bindingMetadata
    }
}

public struct BindingMetadataIR: Sendable, Equatable {
    public let envelopeVersion: WSDLDefinition.SOAPEnvelopeVersion
    public let style: WSDLDefinition.SOAPBindingStyle
    public let bodyUse: WSDLDefinition.SOAPBodyUse

    public init(
        envelopeVersion: WSDLDefinition.SOAPEnvelopeVersion,
        style: WSDLDefinition.SOAPBindingStyle,
        bodyUse: WSDLDefinition.SOAPBodyUse
    ) {
        self.envelopeVersion = envelopeVersion
        self.style = style
        self.bodyUse = bodyUse
    }
}
