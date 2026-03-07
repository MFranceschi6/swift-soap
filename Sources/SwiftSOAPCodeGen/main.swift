import Foundation
import SwiftSOAPCodeGenCore

private enum ExitCode {
    static let success: Int32 = 0
    static let failure: Int32 = 1
}

private func printUsage() {
    print("""
    SwiftSOAPCodeGen

    Usage:
      swift run SwiftSOAPCodeGen --config <path> [options]

    Options:
      --config <path>              Configuration file path (JSON)
      --config-format <format>     Configuration format identifier (default: json)
      --package-root <path>        Base path for relative paths
      --wsdl <path>                Override WSDL path
      --module-name <name>         Override module name
      --output-mode <build|export|both>
      --build-output <path>
      --export-output <path>
      --runtime-targets <async,nio>
      --generation-scope <client,server>
      --target-swift <major.minor>
      --syntax-feature <name>=<true|false> (repeatable)
      --help
    """)
}

private func run() throws {
    let rawArguments = Array(CommandLine.arguments.dropFirst())
    if rawArguments.contains("--help") || rawArguments.contains("-h") {
        printUsage()
        return
    }

    let request = try CodeGenCommandLineParser.parse(arguments: rawArguments)

    guard let configPath = request.configPath else {
        throw CodeGenError(
            code: .invalidInput,
            message: "Missing required '--config' argument."
        )
    }

    let packageRootPath = request.packageRootPath
    let packageRoot = packageRootPath ?? FileManager.default.currentDirectoryPath

    let configurationURL: URL
    if NSString(string: configPath).expandingTildeInPath.hasPrefix("/") {
        configurationURL = URL(fileURLWithPath: NSString(string: configPath).expandingTildeInPath)
    } else {
        configurationURL = URL(fileURLWithPath: configPath, relativeTo: URL(fileURLWithPath: packageRoot)).standardizedFileURL
    }

    let configurationData: Data
    do {
        configurationData = try Data(contentsOf: configurationURL)
    } catch {
        throw CodeGenError(
            code: .invalidConfiguration,
            message: "Unable to load configuration file '\(configurationURL.path)'."
        )
    }

    let configurationDecoder = try CodeGenConfigurationDecoderRegistry.makeDecoder(for: request.configFormat)
    var configuration = try configurationDecoder.decode(data: configurationData)
    configuration.apply(overrides: request.overrides)

    let generator = CodeGenerator()
    let artifacts = try generator.generate(configuration: configuration, packageRootPath: packageRootPath)
    try generator.writeArtifacts(artifacts, configuration: configuration, packageRootPath: packageRootPath)

    let generatedPaths = artifacts.map { $0.fileName }.joined(separator: ", ")
    print("Generated SOAP sources: \(generatedPaths)")
}

private func writeErrorToStandardError(_ message: String) {
    let line = message.hasSuffix("\n") ? message : "\(message)\n"
    guard let data = line.data(using: .utf8) else {
        return
    }
    FileHandle.standardError.write(data)
}

do {
    try run()
    Foundation.exit(ExitCode.success)
} catch {
    writeErrorToStandardError(String(describing: error))
    Foundation.exit(ExitCode.failure)
}
