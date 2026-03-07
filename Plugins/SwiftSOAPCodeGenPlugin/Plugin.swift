import Foundation
import PackagePlugin

private struct PluginCodeGenConfiguration: Decodable {
    let moduleName: String
}

@main
struct SwiftSOAPCodeGenPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let sourceTarget = target as? SourceModuleTarget else {
            return []
        }

        let configPath = sourceTarget.directory.appending("swift-soap-codegen.json")
        guard FileManager.default.fileExists(atPath: configPath.string) else {
            return []
        }

        let generatedOutputDirectory = context.pluginWorkDirectory.appending("GeneratedSources")
        let codeGeneratorTool = try context.tool(named: "SwiftSOAPCodeGen")
        let generatedOutputFile = generatedOutputDirectory.appending(
            "\(try generatedFileName(from: configPath))"
        )

        return [
            .buildCommand(
                displayName: "Generate SOAP sources for \(target.name)",
                executable: codeGeneratorTool.path,
                arguments: [
                    "--config", configPath.string,
                    "--package-root", context.package.directory.string,
                    "--output-mode", "build",
                    "--build-output", generatedOutputDirectory.string
                ],
                inputFiles: [configPath],
                outputFiles: [generatedOutputFile]
            )
        ]
    }

    private func generatedFileName(from configPath: Path) throws -> String {
        let configurationData = try Data(contentsOf: URL(fileURLWithPath: configPath.string))
        let configuration = try JSONDecoder().decode(PluginCodeGenConfiguration.self, from: configurationData)
        return "\(configuration.moduleName)+GeneratedSOAP.swift"
    }
}
