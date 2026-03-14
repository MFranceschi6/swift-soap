import Foundation
import PackagePlugin

private enum PluginError: Error, CustomStringConvertible {
    case listOutputsFailed(terminationStatus: Int32, stderr: String)
    var description: String {
        switch self {
        case let .listOutputsFailed(status, stderr):
            return "SwiftSOAPCodeGen --list-outputs failed (exit \(status)): \(stderr)"
        }
    }
}

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

        // Probe the tool to discover all output file names.
        // Falls back to the single stamp file if the probe fails (e.g., WSDL not yet available).
        let outputFileNames: [String]
        do {
            outputFileNames = try listOutputFileNames(
                toolPath: codeGeneratorTool.path.string,
                configPath: configPath.string,
                packageRoot: context.package.directory.string
            )
        } catch {
            // Log the error to help diagnose issues, then fall back to stamp-only.
            let stampName = (try? stampFileName(from: configPath)) ?? "GeneratedSOAP.swift"
            Diagnostics.warning("SwiftSOAPCodeGenPlugin: --list-outputs probe failed (\(error)); falling back to stamp file '\(stampName)'")
            outputFileNames = [stampName]
        }

        let outputFiles = outputFileNames.map { generatedOutputDirectory.appending($0) }

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
                outputFiles: outputFiles
            )
        ]
    }

    /// Runs the code generator tool with `--list-outputs` to enumerate the files it would
    /// generate, without actually writing anything to disk.
    private func listOutputFileNames(toolPath: String, configPath: String, packageRoot: String) throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        process.arguments = [
            "--config", configPath,
            "--package-root", packageRoot,
            "--output-mode", "build",
            "--list-outputs"
        ]
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrText = String(decoding: stderrData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0 else {
            throw PluginError.listOutputsFailed(terminationStatus: process.terminationStatus, stderr: stderrText)
        }
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        return try JSONDecoder().decode([String].self, from: stdoutData)
    }

    private func stampFileName(from configPath: Path) throws -> String {
        let configurationData = try Data(contentsOf: URL(fileURLWithPath: configPath.string))
        let configuration = try JSONDecoder().decode(PluginCodeGenConfiguration.self, from: configurationData)
        return "\(configuration.moduleName)+GeneratedSOAP.swift"
    }
}
