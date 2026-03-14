import Foundation
// swiftlint:disable:next blanket_disable_command
// swiftlint:disable line_length

public struct SwiftCodeEmitter: SwiftSourceEmitter {
    public init() {}

    // MARK: - Protocol conformance

    public func emit(ir: SOAPCodeGenerationIR, syntaxProfile: CodeGenerationSyntaxProfile) -> [GeneratedSourceArtifact] {
        let fileHeader = makeFileHeader(syntaxProfile: syntaxProfile)
        var artifacts: [GeneratedSourceArtifact] = []

        // Marker file – declared by the build-tool plugin as output stamp for incremental builds.
        // SPM compiles all .swift files found in the plugin work directory automatically.
        artifacts.append(GeneratedSourceArtifact(
            fileName: "\(ir.moduleName)+GeneratedSOAP.swift",
            contents: fileHeader + "\n// Module: \(ir.moduleName)\n"
        ))

        artifacts.append(contentsOf: emitTypeArtifacts(ir: ir, fileHeader: fileHeader))
        artifacts.append(contentsOf: emitOperationsArtifacts(ir: ir, fileHeader: fileHeader))
        artifacts.append(contentsOf: emitClientArtifacts(ir: ir, fileHeader: fileHeader, syntaxProfile: syntaxProfile))
        artifacts.append(contentsOf: emitServerArtifacts(ir: ir, fileHeader: fileHeader, syntaxProfile: syntaxProfile))

        return artifacts
    }
}

// MARK: - Artifact builders

private extension SwiftCodeEmitter {
    func emitTypeArtifacts(ir: SOAPCodeGenerationIR, fileHeader: String) -> [GeneratedSourceArtifact] {
        ir.generatedTypes.map { generatedType in
            var lines: [String] = []
            lines.append(contentsOf: baseImports(forType: generatedType))
            lines.append("")
            lines.append(fileHeader)
            lines.append("")
            lines.append(contentsOf: emitType(generatedType, validationProfile: ir.validationProfile))
            lines.append("")
            return GeneratedSourceArtifact(
                fileName: "\(generatedType.swiftTypeName).swift",
                contents: lines.joined(separator: "\n")
            )
        }
    }

    func emitOperationsArtifacts(ir: SOAPCodeGenerationIR, fileHeader: String) -> [GeneratedSourceArtifact] {
        ir.services.flatMap { service in
            service.ports.map { port in
                let identifierEnumName = "\(service.swiftTypeName)\(port.swiftTypeName)OperationIdentifier"
                let hasActions = port.operations.contains { $0.soapAction != nil }
                let actionEnumName: String? = hasActions
                    ? "\(service.swiftTypeName)\(port.swiftTypeName)OperationAction"
                    : nil
                var lines: [String] = []
                lines.append("import Foundation")
                lines.append("import SwiftSOAPCore")
                lines.append("")
                lines.append(fileHeader)
                lines.append("")
                lines.append(contentsOf: emitOperationEnums(service, port: port))
                lines.append("")
                for operation in port.operations {
                    lines.append(contentsOf: emitOperationContract(
                        operation,
                        identifierEnumName: identifierEnumName,
                        actionEnumName: actionEnumName
                    ))
                    lines.append("")
                }
                return GeneratedSourceArtifact(
                    fileName: "\(service.swiftTypeName)\(port.swiftTypeName)Operations.swift",
                    contents: lines.joined(separator: "\n")
                )
            }
        }
    }

    func emitClientArtifacts(
        ir: SOAPCodeGenerationIR,
        fileHeader: String,
        syntaxProfile: CodeGenerationSyntaxProfile
    ) -> [GeneratedSourceArtifact] {
        var artifacts: [GeneratedSourceArtifact] = []
        guard ir.generationScope.contains(.client) else { return artifacts }

        if ir.runtimeTargets.contains(.async) {
            for service in ir.services {
                for port in service.ports {
                    var lines: [String] = []
                    lines.append("import Foundation")
                    lines.append("import SwiftSOAPCore")
                    lines.append("import SwiftSOAPClientAsync")
                    lines.append("")
                    lines.append(fileHeader)
                    lines.append("")
                    lines.append(contentsOf: emitAsyncClientLines(service: service, port: port, syntaxProfile: syntaxProfile))
                    lines.append("")
                    artifacts.append(GeneratedSourceArtifact(
                        fileName: "\(service.swiftTypeName)\(port.swiftTypeName)AsyncClient.swift",
                        contents: lines.joined(separator: "\n")
                    ))
                }
            }
        }

        if ir.runtimeTargets.contains(.nio) {
            for service in ir.services {
                for port in service.ports {
                    var lines: [String] = []
                    lines.append("import Foundation")
                    lines.append("import NIOCore")
                    lines.append("import SwiftSOAPCore")
                    lines.append("import SwiftSOAPClientNIO")
                    lines.append("")
                    lines.append(fileHeader)
                    lines.append("")
                    lines.append(contentsOf: emitNIOClientLines(service: service, port: port, syntaxProfile: syntaxProfile))
                    lines.append("")
                    artifacts.append(GeneratedSourceArtifact(
                        fileName: "\(service.swiftTypeName)\(port.swiftTypeName)NIOClient.swift",
                        contents: lines.joined(separator: "\n")
                    ))
                }
            }
        }

        return artifacts
    }

    func emitServerArtifacts(
        ir: SOAPCodeGenerationIR,
        fileHeader: String,
        syntaxProfile: CodeGenerationSyntaxProfile
    ) -> [GeneratedSourceArtifact] {
        var artifacts: [GeneratedSourceArtifact] = []
        guard ir.generationScope.contains(.server) else { return artifacts }

        if ir.runtimeTargets.contains(.async) {
            for service in ir.services {
                for port in service.ports {
                    var lines: [String] = []
                    lines.append("import Foundation")
                    lines.append("import SwiftSOAPCore")
                    lines.append("import SwiftSOAPServerAsync")
                    lines.append("")
                    lines.append(fileHeader)
                    lines.append("")
                    lines.append(contentsOf: emitAsyncServerLines(service: service, port: port, syntaxProfile: syntaxProfile))
                    lines.append("")
                    artifacts.append(GeneratedSourceArtifact(
                        fileName: "\(service.swiftTypeName)\(port.swiftTypeName)AsyncServer.swift",
                        contents: lines.joined(separator: "\n")
                    ))
                }
            }
        }

        if ir.runtimeTargets.contains(.nio) {
            for service in ir.services {
                for port in service.ports {
                    var lines: [String] = []
                    lines.append("import Foundation")
                    lines.append("import NIOCore")
                    lines.append("import SwiftSOAPCore")
                    lines.append("import SwiftSOAPServerNIO")
                    lines.append("")
                    lines.append(fileHeader)
                    lines.append("")
                    lines.append(contentsOf: emitNIOServerLines(service: service, port: port, syntaxProfile: syntaxProfile))
                    lines.append("")
                    artifacts.append(GeneratedSourceArtifact(
                        fileName: "\(service.swiftTypeName)\(port.swiftTypeName)NIOServer.swift",
                        contents: lines.joined(separator: "\n")
                    ))
                }
            }
        }

        return artifacts
    }
}

// MARK: - Imports

private extension SwiftCodeEmitter {
    func makeFileHeader(syntaxProfile: CodeGenerationSyntaxProfile) -> String {
        "// Generated by SwiftSOAPCodeGen. Do not edit manually.\n// Target Swift version: \(syntaxProfile.targetSwiftVersion.description)"
    }

    func baseImports(forType generatedType: GeneratedTypeIR) -> [String] {
        var imports = ["import Foundation", "import SwiftSOAPCore"]
        if generatedType.xmlRootElementName != nil {
            imports.append("import SwiftSOAPXML")
        }
        return imports
    }
}

// MARK: - Type emission

private extension SwiftCodeEmitter {
    func emitType(_ generatedType: GeneratedTypeIR, validationProfile: ValidationProfile) -> [String] {
        switch generatedType.kind {
        case .bodyPayload:
            return emitStruct(
                name: generatedType.swiftTypeName,
                protocols: ["SOAPBodyPayload", "Equatable"],
                fields: generatedType.fields,
                xmlRootElementName: generatedType.xmlRootElementName,
                xmlRootElementNamespaceURI: generatedType.xmlRootElementNamespaceURI,
                validationProfile: validationProfile
            )
        case .faultDetailPayload:
            return emitStruct(
                name: generatedType.swiftTypeName,
                protocols: ["SOAPFaultDetailPayload", "Equatable"],
                fields: generatedType.fields,
                xmlRootElementName: nil,
                xmlRootElementNamespaceURI: nil,
                validationProfile: validationProfile
            )
        case .schemaModel:
            return emitStruct(
                name: generatedType.swiftTypeName,
                protocols: ["Codable", "Sendable", "Equatable"],
                fields: generatedType.fields,
                xmlRootElementName: nil,
                xmlRootElementNamespaceURI: nil,
                validationProfile: validationProfile
            )
        case .enumeration:
            return emitEnumType(generatedType)
        }
    }

    func emitEnumType(_ generatedType: GeneratedTypeIR) -> [String] {
        var lines: [String] = []
        lines.append("public enum \(generatedType.swiftTypeName): String, Codable, Sendable, Equatable {")
        for rawValue in generatedType.enumerationCases {
            let caseName = sanitizeEnumCaseName(rawValue)
            if caseName == rawValue {
                lines.append("    case \(caseName)")
            } else {
                lines.append("    case \(caseName) = \"\(rawValue)\"")
            }
        }
        lines.append("}")
        return lines
    }

    // swiftlint:disable:next function_body_length
    func emitStruct(
        name: String,
        protocols: [String],
        fields: [GeneratedTypeFieldIR],
        xmlRootElementName: String?,
        xmlRootElementNamespaceURI: String?,
        validationProfile: ValidationProfile
    ) -> [String] {
        var lines: [String] = []
        var conformances = protocols
        if xmlRootElementName != nil {
            conformances.append("XMLRootNode")
        }

        let orderedFields = fields.sorted { lhs, rhs in
            switch (lhs.xmlOrder, rhs.xmlOrder) {
            case let (lhsOrder?, rhsOrder?): return lhsOrder < rhsOrder
            default: return false
            }
        }

        let needsCodingKeys = orderedFields.contains { field in
            guard let xmlName = field.xmlName else { return false }
            return xmlName != field.name
        }

        lines.append("public struct \(name): \(conformances.joined(separator: ", ")) {")

        if let rootName = xmlRootElementName {
            lines.append("    public static var xmlRootElementName: String { \"\(rootName)\" }")
            if let namespaceURI = xmlRootElementNamespaceURI {
                lines.append("    public static var xmlRootElementNamespaceURI: String? { \"\(namespaceURI)\" }")
            }
            lines.append("")
        }

        if orderedFields.isEmpty {
            lines.append("    public init() {}")
            lines.append("}")
            return lines
        }

        for field in orderedFields {
            let optionalSuffix = field.isOptional ? "?" : ""
            lines.append("    public var \(field.name): \(field.swiftTypeName)\(optionalSuffix)")
        }

        if needsCodingKeys {
            lines.append("")
            lines.append("    public enum CodingKeys: String, CodingKey {")
            for field in orderedFields {
                let xmlName = field.xmlName ?? field.name
                if xmlName != field.name {
                    lines.append("        case \(field.name) = \"\(xmlName)\"")
                } else {
                    lines.append("        case \(field.name)")
                }
            }
            lines.append("    }")
        }

        let initializerSignature = orderedFields
            .map { field -> String in
                let optionalSuffix = field.isOptional ? "?" : ""
                return "\(field.name): \(field.swiftTypeName)\(optionalSuffix)"
            }
            .joined(separator: ", ")
        lines.append("")
        lines.append("    public init(\(initializerSignature)) {")
        for field in orderedFields {
            lines.append("        self.\(field.name) = \(field.name)")
        }
        lines.append("    }")

        if validationProfile == .strict {
            let constrainedFields = orderedFields.filter { !$0.constraints.isEmpty }
            if !constrainedFields.isEmpty {
                lines.append("")
                lines.append("    /// Validates field constraints derived from XSD facets.")
                lines.append("    /// - Throws: `SOAPSemanticValidationError` on constraint violation.")
                lines.append("    public func validate() throws {")
                for field in constrainedFields {
                    lines.append(contentsOf: emitFieldValidation(field: field))
                }
                lines.append("    }")
            }
        }

        lines.append("}")
        return lines
    }

    func emitFieldValidation(field: GeneratedTypeFieldIR) -> [String] {
        var lines: [String] = []
        for constraint in field.constraints {
            switch constraint.kind {
            case .minLength:
                let check = field.isOptional
                    ? "if let v = \(field.name), v.count < \(constraint.value)"
                    : "if \(field.name).count < \(constraint.value)"
                lines.append("        \(check) {")
                lines.append("            throw SOAPSemanticValidationError(field: \"\(field.name)\", code: \"[CG_SEMANTIC_001]\", message: \"Value is shorter than minLength \(constraint.value).\")")
                lines.append("        }")
            case .maxLength:
                let check = field.isOptional
                    ? "if let v = \(field.name), v.count > \(constraint.value)"
                    : "if \(field.name).count > \(constraint.value)"
                lines.append("        \(check) {")
                lines.append("            throw SOAPSemanticValidationError(field: \"\(field.name)\", code: \"[CG_SEMANTIC_002]\", message: \"Value exceeds maxLength \(constraint.value).\")")
                lines.append("        }")
            case .length:
                let check = field.isOptional
                    ? "if let v = \(field.name), v.count != \(constraint.value)"
                    : "if \(field.name).count != \(constraint.value)"
                lines.append("        \(check) {")
                lines.append("            throw SOAPSemanticValidationError(field: \"\(field.name)\", code: \"[CG_SEMANTIC_003]\", message: \"Value length must be exactly \(constraint.value).\")")
                lines.append("        }")
            case .pattern:
                let src = field.isOptional ? "\(field.name) ?? \"\"" : "\(field.name)"
                lines.append("        if (try? NSRegularExpression(pattern: \"\(constraint.value)\"))?.firstMatch(in: \(src), range: NSRange(\(src).startIndex..., in: \(src))) == nil {")
                lines.append("            throw SOAPSemanticValidationError(field: \"\(field.name)\", code: \"[CG_SEMANTIC_004]\", message: \"Value does not match pattern \\\"\(constraint.value)\\\".\")")
                lines.append("        }")
            default:
                break
            }
        }
        return lines
    }

    func sanitizeEnumCaseName(_ rawValue: String) -> String {
        let tokens = rawValue
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return "unknown" }
        var result = tokens[0].prefix(1).lowercased() + tokens[0].dropFirst()
        if tokens.count > 1 {
            for token in tokens.dropFirst() {
                result += token.prefix(1).uppercased() + token.dropFirst().lowercased()
            }
        }
        if let first = result.first, first.isNumber {
            return "value\(result)"
        }
        let reserved: Set<String> = ["class", "struct", "enum", "protocol", "func", "let", "var", "extension", "default", "case"]
        if reserved.contains(result) {
            return "`\(result)`"
        }
        return result
    }
}

// MARK: - Operation emission

private extension SwiftCodeEmitter {
    func emitOperationEnums(_ service: ServiceIR, port: ServicePortIR) -> [String] {
        var lines: [String] = []
        let identifierEnumName = "\(service.swiftTypeName)\(port.swiftTypeName)OperationIdentifier"
        lines.append("/// Typed operation identifiers for \(service.swiftTypeName).\(port.swiftTypeName).")
        lines.append("public enum \(identifierEnumName): String {")
        for operation in port.operations {
            lines.append("    case \(operation.swiftMethodName) = \"\(operation.operationIdentifierRawValue)\"")
        }
        lines.append("}")
        let actionsOps = port.operations.filter { $0.soapAction != nil }
        if !actionsOps.isEmpty {
            let actionEnumName = "\(service.swiftTypeName)\(port.swiftTypeName)OperationAction"
            lines.append("")
            lines.append("/// Typed SOAP actions for \(service.swiftTypeName).\(port.swiftTypeName).")
            lines.append("public enum \(actionEnumName): String {")
            for op in actionsOps {
                if let soapAction = op.soapAction {
                    lines.append("    case \(op.swiftMethodName) = \"\(soapAction)\"")
                }
            }
            lines.append("}")
        }
        return lines
    }

    func emitOperationContract(
        _ operation: OperationIR,
        identifierEnumName: String,
        actionEnumName: String?
    ) -> [String] {
        var lines: [String] = []
        lines.append("public struct \(operation.operationContractTypeName): SOAPBindingOperationContract {")
        lines.append("    public typealias RequestPayload = \(operation.requestPayloadTypeName)")
        lines.append("    public typealias ResponsePayload = \(operation.responsePayloadTypeName)")
        lines.append("    public typealias FaultDetailPayload = \(operation.faultDetailTypeName)")
        lines.append("")
        lines.append("    public static var operationIdentifier: SOAPOperationIdentifier {")
        lines.append("        SOAPOperationIdentifier(\(identifierEnumName).\(operation.swiftMethodName))")
        lines.append("    }")
        lines.append("")
        lines.append("    public static var soapAction: SOAPAction? {")
        if let actionEnumName = actionEnumName, operation.soapAction != nil {
            lines.append("        SOAPAction(\(actionEnumName).\(operation.swiftMethodName))")
        } else {
            lines.append("        nil")
        }
        lines.append("    }")
        lines.append("")
        lines.append("    public static var bindingMetadata: SOAPBindingMetadata {")
        lines.append("        SOAPBindingMetadata(")
        lines.append("            envelopeVersion: .\(operation.bindingMetadata.envelopeVersion.rawValue),")
        lines.append("            style: .\(operation.bindingMetadata.style.rawValue),")
        lines.append("            bodyUse: .\(operation.bindingMetadata.bodyUse.rawValue)")
        lines.append("        )")
        lines.append("    }")
        lines.append("}")
        return lines
    }
}

// MARK: - Client emission

private extension SwiftCodeEmitter {
    func emitAsyncClientLines(
        service: ServiceIR,
        port: ServicePortIR,
        syntaxProfile: CodeGenerationSyntaxProfile
    ) -> [String] {
        let throwsClause = throwsClause(syntaxProfile: syntaxProfile)
        let clientType = existentialType("SOAPClientAsync", syntaxProfile: syntaxProfile)
        let clientTypeName = "\(service.swiftTypeName)\(port.swiftTypeName)AsyncClient"

        var lines: [String] = []
        lines.append("public struct \(clientTypeName): Sendable {")
        lines.append("    public let client: \(clientType)")
        lines.append("    public let endpointURL: URL")
        lines.append("")
        lines.append("    public init(client: \(clientType), endpointURL: URL) {")
        lines.append("        self.client = client")
        lines.append("        self.endpointURL = endpointURL")
        lines.append("    }")
        lines.append("")
        for operation in port.operations {
            lines.append("    public func \(operation.swiftMethodName)(request: \(operation.requestPayloadTypeName)) async \(throwsClause) -> SOAPOperationResponse<\(operation.responsePayloadTypeName), \(operation.faultDetailTypeName)> {")
            lines.append("        try \(operation.operationContractTypeName).validateBinding()")
            lines.append("        return try await client.invoke(\(operation.operationContractTypeName).self, request: request, endpointURL: endpointURL)")
            lines.append("    }")
            lines.append("")
        }
        lines.append("}")
        return lines
    }

    func emitNIOClientLines(
        service: ServiceIR,
        port: ServicePortIR,
        syntaxProfile: CodeGenerationSyntaxProfile
    ) -> [String] {
        let clientType = existentialType("SOAPClientNIO", syntaxProfile: syntaxProfile)
        let clientTypeName = "\(service.swiftTypeName)\(port.swiftTypeName)NIOClient"

        var lines: [String] = []
        lines.append("public struct \(clientTypeName) {")
        lines.append("    public let client: \(clientType)")
        lines.append("    public let endpointURL: URL")
        lines.append("")
        lines.append("    public init(client: \(clientType), endpointURL: URL) {")
        lines.append("        self.client = client")
        lines.append("        self.endpointURL = endpointURL")
        lines.append("    }")
        lines.append("")
        for operation in port.operations {
            lines.append("    public func \(operation.swiftMethodName)(request: \(operation.requestPayloadTypeName), on eventLoop: EventLoop) -> EventLoopFuture<SOAPOperationResponse<\(operation.responsePayloadTypeName), \(operation.faultDetailTypeName)>> {")
            lines.append("        do {")
            lines.append("            try \(operation.operationContractTypeName).validateBinding()")
            lines.append("        } catch {")
            lines.append("            return eventLoop.makeFailedFuture(error)")
            lines.append("        }")
            lines.append("        return client.invoke(\(operation.operationContractTypeName).self, request: request, endpointURL: endpointURL, on: eventLoop)")
            lines.append("    }")
            lines.append("")
        }
        lines.append("}")
        return lines
    }
}

// MARK: - Server emission

private extension SwiftCodeEmitter {
    func emitAsyncServerLines(
        service: ServiceIR,
        port: ServicePortIR,
        syntaxProfile: CodeGenerationSyntaxProfile
    ) -> [String] {
        let throwsClause = throwsClause(syntaxProfile: syntaxProfile)
        let implementationTypePrefix = existentialTypePrefix(syntaxProfile: syntaxProfile)
        let serverType = existentialType("SOAPServerAsync", syntaxProfile: syntaxProfile)
        let protocolTypeName = "\(service.swiftTypeName)\(port.swiftTypeName)AsyncService"
        let registrarTypeName = "\(service.swiftTypeName)\(port.swiftTypeName)AsyncServerRegistrar"

        var lines: [String] = []
        lines.append("public protocol \(protocolTypeName): Sendable {")
        for operation in port.operations {
            lines.append("    func \(operation.swiftMethodName)(request: \(operation.requestPayloadTypeName)) async \(throwsClause) -> SOAPOperationResponse<\(operation.responsePayloadTypeName), \(operation.faultDetailTypeName)>")
        }
        lines.append("}")
        lines.append("")
        lines.append("public struct \(registrarTypeName): Sendable {")
        lines.append("    public let server: \(serverType)")
        lines.append("")
        lines.append("    public init(server: \(serverType)) {")
        lines.append("        self.server = server")
        lines.append("    }")
        lines.append("")
        lines.append("    public func register(implementation: \(implementationTypePrefix)\(protocolTypeName)) async \(throwsClause) {")
        for operation in port.operations {
            lines.append("        try \(operation.operationContractTypeName).validateBinding()")
            lines.append("        try await server.register(\(operation.operationContractTypeName).self) { request in")
            lines.append("            try await implementation.\(operation.swiftMethodName)(request: request)")
            lines.append("        }")
        }
        lines.append("    }")
        lines.append("}")
        return lines
    }

    func emitNIOServerLines(
        service: ServiceIR,
        port: ServicePortIR,
        syntaxProfile: CodeGenerationSyntaxProfile
    ) -> [String] {
        let implementationTypePrefix = existentialTypePrefix(syntaxProfile: syntaxProfile)
        let serverType = existentialType("SOAPServerNIO", syntaxProfile: syntaxProfile)
        let protocolTypeName = "\(service.swiftTypeName)\(port.swiftTypeName)NIOService"
        let registrarTypeName = "\(service.swiftTypeName)\(port.swiftTypeName)NIOServerRegistrar"

        var lines: [String] = []
        lines.append("public protocol \(protocolTypeName) {")
        for operation in port.operations {
            lines.append("    func \(operation.swiftMethodName)(request: \(operation.requestPayloadTypeName), on eventLoop: EventLoop) -> EventLoopFuture<SOAPOperationResponse<\(operation.responsePayloadTypeName), \(operation.faultDetailTypeName)>>")
        }
        lines.append("}")
        lines.append("")
        lines.append("public struct \(registrarTypeName) {")
        lines.append("    public let server: \(serverType)")
        lines.append("")
        lines.append("    public init(server: \(serverType)) {")
        lines.append("        self.server = server")
        lines.append("    }")
        lines.append("")
        lines.append("    public func register(implementation: \(implementationTypePrefix)\(protocolTypeName)) {")
        for operation in port.operations {
            lines.append("        server.register(\(operation.operationContractTypeName).self) { request, eventLoop in")
            lines.append("            do {")
            lines.append("                try \(operation.operationContractTypeName).validateBinding()")
            lines.append("            } catch {")
            lines.append("                return eventLoop.makeFailedFuture(error)")
            lines.append("            }")
            lines.append("            return implementation.\(operation.swiftMethodName)(request: request, on: eventLoop)")
            lines.append("        }")
        }
        lines.append("    }")
        lines.append("}")
        return lines
    }
}

// MARK: - Helpers

private extension SwiftCodeEmitter {
    func throwsClause(syntaxProfile: CodeGenerationSyntaxProfile) -> String {
        syntaxProfile.useTypedThrowsAnyError ? "throws(any Error)" : "throws"
    }

    func existentialType(_ protocolName: String, syntaxProfile: CodeGenerationSyntaxProfile) -> String {
        "\(existentialTypePrefix(syntaxProfile: syntaxProfile))\(protocolName)"
    }

    func existentialTypePrefix(syntaxProfile: CodeGenerationSyntaxProfile) -> String {
        syntaxProfile.useExistentialAny ? "any " : ""
    }
}
