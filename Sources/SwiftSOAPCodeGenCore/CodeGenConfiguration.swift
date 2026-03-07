import Foundation

public enum CodeGenerationScopeOption: String, Codable, Sendable, CaseIterable {
    case client
    case server
}

public enum CodeGenerationRuntimeTargetOption: String, Codable, Sendable, CaseIterable {
    case async
    case nio
}

public enum CodeGenerationOutputMode: String, Codable, Sendable, CaseIterable {
    case build
    case `export`
    case both
}

public struct SwiftLanguageVersion: Sendable, Equatable, Hashable, Comparable, Codable {
    public let major: Int
    public let minor: Int

    public init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }

    public init(parsing rawValue: String) throws {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)

        guard parts.count == 2,
              let major = Int(parts[0]),
              let minor = Int(parts[1]),
              major >= 0,
              minor >= 0 else {
            throw CodeGenError(
                code: .invalidConfiguration,
                message: "Invalid Swift version '\(rawValue)'.",
                suggestion: "Use 'major.minor' format, for example '5.6' or '6.0'."
            )
        }

        self.init(major: major, minor: minor)
    }

    public static func < (lhs: SwiftLanguageVersion, rhs: SwiftLanguageVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        return lhs.minor < rhs.minor
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = try SwiftLanguageVersion(parsing: rawValue)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

extension SwiftLanguageVersion: CustomStringConvertible {
    public var description: String {
        "\(major).\(minor)"
    }
}

public enum CodeGenSyntaxFeature: String, Sendable, Codable, CaseIterable {
    case existentialAny
    case typedThrowsAnyError
}

public struct CodeGenSyntaxFeaturePolicy: Sendable, Equatable {
    public let introducedIn: SwiftLanguageVersion
    public let mandatoryFrom: SwiftLanguageVersion?
    public let affectsPublicAPI: Bool

    public init(
        introducedIn: SwiftLanguageVersion,
        mandatoryFrom: SwiftLanguageVersion?,
        affectsPublicAPI: Bool
    ) {
        self.introducedIn = introducedIn
        self.mandatoryFrom = mandatoryFrom
        self.affectsPublicAPI = affectsPublicAPI
    }
}

public struct CodeGenerationSyntaxProfile: Sendable, Equatable {
    public let targetSwiftVersion: SwiftLanguageVersion
    public let useExistentialAny: Bool
    public let useTypedThrowsAnyError: Bool

    public init(
        targetSwiftVersion: SwiftLanguageVersion,
        useExistentialAny: Bool,
        useTypedThrowsAnyError: Bool
    ) {
        self.targetSwiftVersion = targetSwiftVersion
        self.useExistentialAny = useExistentialAny
        self.useTypedThrowsAnyError = useTypedThrowsAnyError
    }
}

public enum CodeGenSyntaxFeatureRegistry {
    public static func policy(for feature: CodeGenSyntaxFeature) -> CodeGenSyntaxFeaturePolicy {
        switch feature {
        case .existentialAny:
            return CodeGenSyntaxFeaturePolicy(
                introducedIn: SwiftLanguageVersion(major: 5, minor: 6),
                mandatoryFrom: SwiftLanguageVersion(major: 6, minor: 0),
                affectsPublicAPI: true
            )
        case .typedThrowsAnyError:
            return CodeGenSyntaxFeaturePolicy(
                introducedIn: SwiftLanguageVersion(major: 6, minor: 0),
                mandatoryFrom: nil,
                affectsPublicAPI: true
            )
        }
    }

    public static func parseFeatureOverrides(_ overrides: [String: Bool]) throws -> [CodeGenSyntaxFeature: Bool] {
        var resolved: [CodeGenSyntaxFeature: Bool] = [:]
        for (rawName, enabled) in overrides {
            guard let feature = CodeGenSyntaxFeature(rawValue: rawName) else {
                throw CodeGenError(
                    code: .invalidSyntaxFeature,
                    message: "Unknown syntax feature '\(rawName)'.",
                    suggestion: "Supported features: \(CodeGenSyntaxFeature.allCases.map { $0.rawValue }.sorted().joined(separator: ", "))."
                )
            }
            resolved[feature] = enabled
        }
        return resolved
    }

    public static func resolveProfile(
        targetSwiftVersion: SwiftLanguageVersion,
        featureOverrides: [String: Bool]
    ) throws -> CodeGenerationSyntaxProfile {
        let typedOverrides = try parseFeatureOverrides(featureOverrides)
        var resolvedValues: [CodeGenSyntaxFeature: Bool] = [:]

        for feature in CodeGenSyntaxFeature.allCases {
            let policy = policy(for: feature)
            let defaultValue = targetSwiftVersion >= policy.introducedIn
            let value = typedOverrides[feature] ?? defaultValue

            if value, targetSwiftVersion < policy.introducedIn {
                throw CodeGenError(
                    code: .invalidSyntaxFeature,
                    message: "Feature '\(feature.rawValue)' requires Swift \(policy.introducedIn.description)+, target is \(targetSwiftVersion.description)."
                )
            }

            if let mandatoryFrom = policy.mandatoryFrom,
               targetSwiftVersion >= mandatoryFrom,
               value == false {
                throw CodeGenError(
                    code: .invalidSyntaxFeature,
                    message: "Feature '\(feature.rawValue)' is mandatory for Swift \(mandatoryFrom.description)+ targets."
                )
            }

            resolvedValues[feature] = value
        }

        return CodeGenerationSyntaxProfile(
            targetSwiftVersion: targetSwiftVersion,
            useExistentialAny: resolvedValues[.existentialAny] ?? false,
            useTypedThrowsAnyError: resolvedValues[.typedThrowsAnyError] ?? false
        )
    }
}

public struct CodeGenConfiguration: Codable, Sendable, Equatable {
    public var wsdlPath: String
    public var moduleName: String
    public var outputMode: CodeGenerationOutputMode
    public var buildOutputDirectory: String
    public var exportOutputDirectory: String
    public var runtimeTargets: Set<CodeGenerationRuntimeTargetOption>
    public var generationScope: Set<CodeGenerationScopeOption>
    public var targetSwiftVersion: SwiftLanguageVersion
    public var syntaxFeatures: [String: Bool]

    public init(
        wsdlPath: String,
        moduleName: String,
        outputMode: CodeGenerationOutputMode = .build,
        buildOutputDirectory: String = ".build/swift-soap-codegen",
        exportOutputDirectory: String = "Sources/Generated",
        runtimeTargets: Set<CodeGenerationRuntimeTargetOption> = [.async],
        generationScope: Set<CodeGenerationScopeOption> = [.client],
        targetSwiftVersion: SwiftLanguageVersion,
        syntaxFeatures: [String: Bool] = [:]
    ) {
        self.wsdlPath = wsdlPath
        self.moduleName = moduleName
        self.outputMode = outputMode
        self.buildOutputDirectory = buildOutputDirectory
        self.exportOutputDirectory = exportOutputDirectory
        self.runtimeTargets = runtimeTargets
        self.generationScope = generationScope
        self.targetSwiftVersion = targetSwiftVersion
        self.syntaxFeatures = syntaxFeatures
    }
}

public struct CodeGenConfigurationOverrides: Sendable, Equatable {
    public var wsdlPath: String?
    public var moduleName: String?
    public var outputMode: CodeGenerationOutputMode?
    public var buildOutputDirectory: String?
    public var exportOutputDirectory: String?
    public var runtimeTargets: Set<CodeGenerationRuntimeTargetOption>?
    public var generationScope: Set<CodeGenerationScopeOption>?
    public var targetSwiftVersion: SwiftLanguageVersion?
    public var syntaxFeatures: [String: Bool]

    public init() {
        syntaxFeatures = [:]
    }
}

public extension CodeGenConfiguration {
    mutating func apply(overrides: CodeGenConfigurationOverrides) {
        if let wsdlPath = overrides.wsdlPath {
            self.wsdlPath = wsdlPath
        }
        if let moduleName = overrides.moduleName {
            self.moduleName = moduleName
        }
        if let outputMode = overrides.outputMode {
            self.outputMode = outputMode
        }
        if let buildOutputDirectory = overrides.buildOutputDirectory {
            self.buildOutputDirectory = buildOutputDirectory
        }
        if let exportOutputDirectory = overrides.exportOutputDirectory {
            self.exportOutputDirectory = exportOutputDirectory
        }
        if let runtimeTargets = overrides.runtimeTargets {
            self.runtimeTargets = runtimeTargets
        }
        if let generationScope = overrides.generationScope {
            self.generationScope = generationScope
        }
        if let targetSwiftVersion = overrides.targetSwiftVersion {
            self.targetSwiftVersion = targetSwiftVersion
        }
        for (featureName, enabled) in overrides.syntaxFeatures {
            syntaxFeatures[featureName] = enabled
        }
    }

    func resolvedSyntaxProfile() throws -> CodeGenerationSyntaxProfile {
        try validateRuntimeTargets()
        return try CodeGenSyntaxFeatureRegistry.resolveProfile(
            targetSwiftVersion: targetSwiftVersion,
            featureOverrides: syntaxFeatures
        )
    }

    private func validateRuntimeTargets() throws {
        if runtimeTargets.contains(.async), targetSwiftVersion < SwiftLanguageVersion(major: 5, minor: 5) {
            throw CodeGenError(
                code: .unsupportedSwiftTarget,
                message: "Runtime target 'async' requires Swift 5.5+, target is \(targetSwiftVersion.description)."
            )
        }
    }
}

public protocol CodeGenConfigurationDecoder {
    var formatIdentifier: String { get }
    func decode(data: Data) throws -> CodeGenConfiguration
}

public struct JSONCodeGenConfigurationDecoder: CodeGenConfigurationDecoder {
    public let formatIdentifier: String = "json"

    public init() {}

    public func decode(data: Data) throws -> CodeGenConfiguration {
        let decoder = JSONDecoder()
        return try decoder.decode(CodeGenConfiguration.self, from: data)
    }
}

public enum CodeGenConfigurationDecoderRegistry {
    public static func makeDecoder(for formatIdentifier: String) throws -> any CodeGenConfigurationDecoder {
        if formatIdentifier == "json" {
            return JSONCodeGenConfigurationDecoder()
        }

        throw CodeGenError(
            code: .invalidConfiguration,
            message: "Unsupported configuration format '\(formatIdentifier)'.",
            suggestion: "Use 'json' or register a new decoder implementation."
        )
    }
}
