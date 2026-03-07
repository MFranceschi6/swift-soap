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

        let configURL = sourceTarget.directoryURL.appendingPathComponent("swift-soap-codegen.json")
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return []
        }

        let generatedOutputDirectoryURL = context.pluginWorkDirectoryURL.appendingPathComponent("GeneratedSources")
        let codeGeneratorTool = try context.tool(named: "SwiftSOAPCodeGen")
        let generatedOutputFileURL = generatedOutputDirectoryURL.appendingPathComponent(
            try generatedFileName(from: configURL)
        )

        return [
            .buildCommand(
                displayName: "Generate SOAP sources for \(target.name)",
                executable: codeGeneratorTool.url,
                arguments: [
                    "--config", configURL.path,
                    "--package-root", context.package.directoryURL.path,
                    "--output-mode", "build",
                    "--build-output", generatedOutputDirectoryURL.path
                ],
                inputFiles: [configURL],
                outputFiles: [generatedOutputFileURL]
            )
        ]
    }

    private func generatedFileName(from configURL: URL) throws -> String {
        let configurationData = try Data(contentsOf: configURL)
        let configuration = try JSONDecoder().decode(PluginCodeGenConfiguration.self, from: configurationData)
        return "\(configuration.moduleName)+GeneratedSOAP.swift"
    }
}
