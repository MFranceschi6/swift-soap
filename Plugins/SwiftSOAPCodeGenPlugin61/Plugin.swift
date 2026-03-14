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

        let configURL = sourceTarget.directoryURL.appendingPathComponent("swift-soap-codegen.json")
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return []
        }

        let generatedOutputDirectoryURL = context.pluginWorkDirectoryURL.appendingPathComponent("GeneratedSources")
        let codeGeneratorTool = try context.tool(named: "SwiftSOAPCodeGen")

        // Probe the tool to discover all output file names.
        // Falls back to the single stamp file if the probe fails (e.g., WSDL not yet available).
        let outputFileNames: [String]
        do {
            outputFileNames = try listOutputFileNames(
                toolURL: codeGeneratorTool.url,
                configPath: configURL.path,
                packageRoot: context.package.directoryURL.path
            )
        } catch {
            // Log the error to help diagnose issues, then fall back to stamp-only.
            let stampName = (try? stampFileName(from: configURL)) ?? "GeneratedSOAP.swift"
            Diagnostics.warning("SwiftSOAPCodeGenPlugin: --list-outputs probe failed (\(error)); falling back to stamp file '\(stampName)'")
            outputFileNames = [stampName]
        }

        let outputFiles = outputFileNames.map { generatedOutputDirectoryURL.appendingPathComponent($0) }

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
                outputFiles: outputFiles
            )
        ]
    }

    /// Runs the code generator tool with `--list-outputs` to enumerate the files it would
    /// generate, without actually writing anything to disk.
    private func listOutputFileNames(toolURL: URL, configPath: String, packageRoot: String) throws -> [String] {
        let process = Process()
        process.executableURL = toolURL
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

    private func stampFileName(from configURL: URL) throws -> String {
        let configurationData = try Data(contentsOf: configURL)
        let configuration = try JSONDecoder().decode(PluginCodeGenConfiguration.self, from: configurationData)
        return "\(configuration.moduleName)+GeneratedSOAP.swift"
    }
}
