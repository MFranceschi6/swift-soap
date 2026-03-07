import SwiftSOAPCodeGenCore
import XCTest

final class CodeGenCommandLineParserTests: XCTestCase {
    func test_parse_extractsConfigAndOverrides() throws {
        let request = try CodeGenCommandLineParser.parse(arguments: [
            "--config", "config.json",
            "--config-format", "json",
            "--package-root", "/tmp/project",
            "--wsdl", "service.wsdl",
            "--module-name", "GeneratedSOAP",
            "--output-mode", "both",
            "--build-output", ".build/generated",
            "--export-output", "Sources/Generated",
            "--runtime-targets", "async,nio",
            "--generation-scope", "client,server",
            "--target-swift", "6.0",
            "--syntax-feature", "typedThrowsAnyError=true",
            "--syntax-feature", "existentialAny=false"
        ])

        XCTAssertEqual(request.configPath, "config.json")
        XCTAssertEqual(request.configFormat, "json")
        XCTAssertEqual(request.packageRootPath, "/tmp/project")
        XCTAssertEqual(request.overrides.wsdlPath, "service.wsdl")
        XCTAssertEqual(request.overrides.moduleName, "GeneratedSOAP")
        XCTAssertEqual(request.overrides.outputMode, .both)
        XCTAssertEqual(request.overrides.runtimeTargets, [.async, .nio])
        XCTAssertEqual(request.overrides.generationScope, [.client, .server])
        XCTAssertEqual(request.overrides.targetSwiftVersion, SwiftLanguageVersion(major: 6, minor: 0))
        XCTAssertEqual(request.overrides.syntaxFeatures["typedThrowsAnyError"], true)
        XCTAssertEqual(request.overrides.syntaxFeatures["existentialAny"], false)
    }

    func test_parse_withUnknownFlag_throwsInvalidInput() {
        XCTAssertThrowsError(try CodeGenCommandLineParser.parse(arguments: ["--unknown"])) { error in
            guard let codeGenError = error as? CodeGenError else {
                return XCTFail("Expected CodeGenError, got \(error)")
            }
            XCTAssertEqual(codeGenError.code, .invalidInput)
        }
    }

    func test_parse_withInvalidSyntaxFeaturePair_throwsInvalidInput() {
        XCTAssertThrowsError(try CodeGenCommandLineParser.parse(arguments: [
            "--syntax-feature", "typedThrowsAnyError"
        ])) { error in
            guard let codeGenError = error as? CodeGenError else {
                return XCTFail("Expected CodeGenError, got \(error)")
            }
            XCTAssertEqual(codeGenError.code, .invalidInput)
        }
    }
}
