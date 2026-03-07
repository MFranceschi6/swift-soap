import Foundation

public struct CodeGenCommandLineRequest: Sendable, Equatable {
    public var configPath: String?
    public var configFormat: String
    public var packageRootPath: String?
    public var overrides: CodeGenConfigurationOverrides

    public init(
        configPath: String?,
        configFormat: String = "json",
        packageRootPath: String? = nil,
        overrides: CodeGenConfigurationOverrides = CodeGenConfigurationOverrides()
    ) {
        self.configPath = configPath
        self.configFormat = configFormat
        self.packageRootPath = packageRootPath
        self.overrides = overrides
    }
}

public enum CodeGenCommandLineParser {
    public static func parse(arguments: [String]) throws -> CodeGenCommandLineRequest {
        var index = 0
        var request = CodeGenCommandLineRequest(configPath: nil)

        func requireValue(for flag: String) throws -> String {
            let nextIndex = index + 1
            guard nextIndex < arguments.count else {
                throw CodeGenError(
                    code: .invalidInput,
                    message: "Missing value for flag '\(flag)'."
                )
            }
            return arguments[nextIndex]
        }

        while index < arguments.count {
            let argument = arguments[index]

            switch argument {
            case "--config":
                request.configPath = try requireValue(for: argument)
                index += 2
            case "--config-format":
                request.configFormat = try requireValue(for: argument)
                index += 2
            case "--package-root":
                request.packageRootPath = try requireValue(for: argument)
                index += 2
            case "--wsdl":
                request.overrides.wsdlPath = try requireValue(for: argument)
                index += 2
            case "--module-name":
                request.overrides.moduleName = try requireValue(for: argument)
                index += 2
            case "--output-mode":
                let value = try requireValue(for: argument)
                guard let outputMode = CodeGenerationOutputMode(rawValue: value) else {
                    throw CodeGenError(
                        code: .invalidInput,
                        message: "Invalid output mode '\(value)'."
                    )
                }
                request.overrides.outputMode = outputMode
                index += 2
            case "--build-output":
                request.overrides.buildOutputDirectory = try requireValue(for: argument)
                index += 2
            case "--export-output":
                request.overrides.exportOutputDirectory = try requireValue(for: argument)
                index += 2
            case "--runtime-targets":
                let value = try requireValue(for: argument)
                request.overrides.runtimeTargets = try parseRuntimeTargets(value)
                index += 2
            case "--generation-scope":
                let value = try requireValue(for: argument)
                request.overrides.generationScope = try parseGenerationScope(value)
                index += 2
            case "--target-swift":
                let value = try requireValue(for: argument)
                request.overrides.targetSwiftVersion = try SwiftLanguageVersion(parsing: value)
                index += 2
            case "--syntax-feature":
                let value = try requireValue(for: argument)
                let (name, enabled) = try parseSyntaxFeatureOverride(value)
                request.overrides.syntaxFeatures[name] = enabled
                index += 2
            case "--help", "-h":
                index += 1
            default:
                throw CodeGenError(
                    code: .invalidInput,
                    message: "Unknown argument '\(argument)'."
                )
            }
        }

        return request
    }

    private static func parseRuntimeTargets(_ value: String) throws -> Set<CodeGenerationRuntimeTargetOption> {
        let parts = value
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let targets = try parts.map { part -> CodeGenerationRuntimeTargetOption in
            guard let target = CodeGenerationRuntimeTargetOption(rawValue: part) else {
                throw CodeGenError(
                    code: .invalidInput,
                    message: "Invalid runtime target '\(part)'."
                )
            }
            return target
        }

        return Set(targets)
    }

    private static func parseGenerationScope(_ value: String) throws -> Set<CodeGenerationScopeOption> {
        let parts = value
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let scopes = try parts.map { part -> CodeGenerationScopeOption in
            guard let scope = CodeGenerationScopeOption(rawValue: part) else {
                throw CodeGenError(
                    code: .invalidInput,
                    message: "Invalid generation scope '\(part)'."
                )
            }
            return scope
        }

        return Set(scopes)
    }

    private static func parseSyntaxFeatureOverride(_ value: String) throws -> (String, Bool) {
        let parts = value.split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            throw CodeGenError(
                code: .invalidInput,
                message: "Invalid syntax feature override '\(value)'.",
                suggestion: "Use '--syntax-feature <feature>=<true|false>'."
            )
        }

        let featureName = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let rawEnabled = parts[1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let enabled: Bool
        switch rawEnabled {
        case "true":
            enabled = true
        case "false":
            enabled = false
        default:
            throw CodeGenError(
                code: .invalidInput,
                message: "Invalid syntax feature value '\(parts[1])' for '\(featureName)'.",
                suggestion: "Use 'true' or 'false'."
            )
        }

        return (featureName, enabled)
    }
}
