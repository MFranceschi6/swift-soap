import Foundation
import SwiftSOAPCodeGenCore

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
      --list-outputs               Print expected output file names as JSON and exit (no files written)
      --help
    """)
}

private func run() throws {
    let rawArguments = Array(CommandLine.arguments.dropFirst())
    if rawArguments.contains("--help") || rawArguments.contains("-h") {
        printUsage()
        return
    }

    // Strip --list-outputs before passing to the generic parser; it is handled separately below.
    let listOutputsRequested = rawArguments.contains("--list-outputs")
    let parserArguments = rawArguments.filter { $0 != "--list-outputs" }

    let request = try CodeGenCommandLineParser.parse(arguments: parserArguments)

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

    // --list-outputs: print generated file names as JSON and exit without writing.
    // Used by the SPM build-tool plugin to enumerate output files before registering
    // the build command, so that all generated .swift files are declared as outputs
    // and are compiled by the Swift compiler.
    if listOutputsRequested {
        let fileNames = artifacts.map(\.fileName)
        let jsonData = try JSONEncoder().encode(fileNames)
        print(String(bytes: jsonData, encoding: .utf8) ?? "[]")
        return
    }

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
    Foundation.exit(0)
} catch {
    writeErrorToStandardError(String(describing: error))
    Foundation.exit(1)
}
