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
        let swiftOutput = emitter.emit(ir: ir, syntaxProfile: syntaxProfile)
        let fileName = "\(ir.moduleName)+GeneratedSOAP.swift"

        return [GeneratedSourceArtifact(fileName: fileName, contents: swiftOutput)]
    }

    public func writeArtifacts(
        _ artifacts: [GeneratedSourceArtifact],
        configuration: CodeGenConfiguration,
        packageRootPath: String? = nil
    ) throws {
        let packageRootURL = resolvedPackageRootURL(path: packageRootPath)

        let outputDirectories = resolveOutputDirectories(
            configuration: configuration,
            packageRootURL: packageRootURL
        )

        for outputDirectory in outputDirectories {
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

    private func resolveOutputDirectories(
        configuration: CodeGenConfiguration,
        packageRootURL: URL
    ) -> [URL] {
        switch configuration.outputMode {
        case .build:
            return [resolvePath(configuration.buildOutputDirectory, relativeTo: packageRootURL)]
        case .export:
            return [resolvePath(configuration.exportOutputDirectory, relativeTo: packageRootURL)]
        case .both:
            return [
                resolvePath(configuration.buildOutputDirectory, relativeTo: packageRootURL),
                resolvePath(configuration.exportOutputDirectory, relativeTo: packageRootURL)
            ]
        }
    }
}
