import Foundation
import SwiftSOAPWSDL

public struct SOAPCodeGenerationIR: Sendable, Equatable {
    public let moduleName: String
    public let generationScope: Set<CodeGenerationScopeOption>
    public let runtimeTargets: Set<CodeGenerationRuntimeTargetOption>
    public let generatedTypes: [GeneratedTypeIR]
    public let services: [ServiceIR]

    public init(
        moduleName: String,
        generationScope: Set<CodeGenerationScopeOption>,
        runtimeTargets: Set<CodeGenerationRuntimeTargetOption>,
        generatedTypes: [GeneratedTypeIR],
        services: [ServiceIR]
    ) {
        self.moduleName = moduleName
        self.generationScope = generationScope
        self.runtimeTargets = runtimeTargets
        self.generatedTypes = generatedTypes
        self.services = services
    }
}

public enum GeneratedTypeKind: String, Sendable, Equatable {
    case bodyPayload
    case faultDetailPayload
    case schemaModel
}

public struct GeneratedTypeFieldIR: Sendable, Equatable {
    public let name: String
    public let swiftTypeName: String
    public let isOptional: Bool

    public init(name: String, swiftTypeName: String, isOptional: Bool) {
        self.name = name
        self.swiftTypeName = swiftTypeName
        self.isOptional = isOptional
    }
}

public struct GeneratedTypeIR: Sendable, Equatable {
    public let swiftTypeName: String
    public let kind: GeneratedTypeKind
    public let fields: [GeneratedTypeFieldIR]

    public init(swiftTypeName: String, kind: GeneratedTypeKind, fields: [GeneratedTypeFieldIR]) {
        self.swiftTypeName = swiftTypeName
        self.kind = kind
        self.fields = fields
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
