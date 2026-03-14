import Foundation
import SwiftSOAPWSDL

public struct GeneratedSourceArtifact: Sendable, Equatable {
    public let fileName: String
    public let contents: String

    public init(fileName: String, contents: String) {
        self.fileName = fileName
        self.contents = contents
    }
}

public struct CodeGenerator {
    private let parser: WSDLDocumentParser
    private let irBuilder: CodeGenerationIRBuilder
    private let emitter: any SwiftSourceEmitter

    public init(
        parser: WSDLDocumentParser = WSDLDocumentParser(),
        irBuilder: CodeGenerationIRBuilder = CodeGenerationIRBuilder(),
        emitter: any SwiftSourceEmitter = EmitterFactory.makeEmitter()
    ) {
        self.parser = parser
        self.irBuilder = irBuilder
        self.emitter = emitter
    }

    public func generate(configuration: CodeGenConfiguration, packageRootPath: String? = nil) throws -> [GeneratedSourceArtifact] {
        let packageRootURL = resolvedPackageRootURL(path: packageRootPath)
        let wsdlURL = resolvePath(configuration.wsdlPath, relativeTo: packageRootURL)

        let wsdlData: Data
        do {
            wsdlData = try Data(contentsOf: wsdlURL)
        } catch {
            throw CodeGenError(
                code: .invalidInput,
                message: "Unable to load WSDL file '\(wsdlURL.path)'."
            )
        }

        let definition: WSDLDefinition
        do {
            definition = try parser.parse(data: wsdlData, sourceURL: wsdlURL)
        } catch {
            throw CodeGenError(
                code: .invalidInput,
                message: "Unable to parse WSDL file '\(wsdlURL.path)': \(error)."
            )
        }

        let ir = try irBuilder.build(from: definition, configuration: configuration)
        let syntaxProfile = try configuration.resolvedSyntaxProfile()
        return emitter.emit(ir: ir, syntaxProfile: syntaxProfile)
    }

    /// Writes generated artifacts to disk.
    ///
    /// Both `.build` and `.export` modes write one `.swift` file per artifact.
    /// The SPM build-tool plugin discovers the full set of output files at build-graph setup
    /// time by running the tool with `--list-outputs`, so every generated file is declared
    /// as a build command output and is compiled by the Swift compiler.
    /// `.both` writes to both directories.
    public func writeArtifacts(
        _ artifacts: [GeneratedSourceArtifact],
        configuration: CodeGenConfiguration,
        packageRootPath: String? = nil
    ) throws {
        let packageRootURL = resolvedPackageRootURL(path: packageRootPath)

        if configuration.outputMode == .build || configuration.outputMode == .both {
            try writeBuildArtifacts(artifacts, configuration: configuration, packageRootURL: packageRootURL)
        }
        if configuration.outputMode == .export || configuration.outputMode == .both {
            try writeExportArtifacts(artifacts, configuration: configuration, packageRootURL: packageRootURL)
        }
    }

    private func resolvedPackageRootURL(path: String?) -> URL {
        let basePath = path ?? FileManager.default.currentDirectoryPath
        return URL(fileURLWithPath: basePath, isDirectory: true)
    }

    private func resolvePath(_ path: String, relativeTo packageRootURL: URL) -> URL {
        let expandedPath = NSString(string: path).expandingTildeInPath
        if expandedPath.hasPrefix("/") {
            return URL(fileURLWithPath: expandedPath)
        }

        return URL(fileURLWithPath: expandedPath, relativeTo: packageRootURL).standardizedFileURL
    }

    /// Writes each artifact as a separate `.swift` file in the build output directory.
    private func writeBuildArtifacts(
        _ artifacts: [GeneratedSourceArtifact],
        configuration: CodeGenConfiguration,
        packageRootURL: URL
    ) throws {
        let outputDirectory = resolvePath(configuration.buildOutputDirectory, relativeTo: packageRootURL)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        for artifact in artifacts {
            let outputFileURL = outputDirectory.appendingPathComponent(artifact.fileName)
            do {
                try artifact.contents.write(to: outputFileURL, atomically: true, encoding: .utf8)
            } catch {
                throw CodeGenError(
                    code: .invalidConfiguration,
                    message: "Unable to write generated source '\(outputFileURL.path)'."
                )
            }
        }
    }

    /// Writes each artifact as a separate `.swift` file in the export output directory.
    private func writeExportArtifacts(
        _ artifacts: [GeneratedSourceArtifact],
        configuration: CodeGenConfiguration,
        packageRootURL: URL
    ) throws {
        let outputDirectory = resolvePath(configuration.exportOutputDirectory, relativeTo: packageRootURL)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        for artifact in artifacts {
            let outputFileURL = outputDirectory.appendingPathComponent(artifact.fileName)
            do {
                try artifact.contents.write(to: outputFileURL, atomically: true, encoding: .utf8)
            } catch {
                throw CodeGenError(
                    code: .invalidConfiguration,
                    message: "Unable to write generated source '\(outputFileURL.path)'."
                )
            }
        }
    }
}
