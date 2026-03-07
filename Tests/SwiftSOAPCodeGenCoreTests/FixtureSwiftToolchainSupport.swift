import Foundation
import SwiftSOAPCodeGenCore

struct FixtureSwiftToolchainSupport {
    let compilerVersion: SwiftLanguageVersion

    static let current = FixtureSwiftToolchainSupport(
        compilerVersion: detectCompilerVersion()
    )

    var fixtureToolsVersion: String {
        if compilerVersion >= SwiftLanguageVersion(major: 6, minor: 1) {
            return "6.1"
        }
        if compilerVersion >= SwiftLanguageVersion(major: 6, minor: 0) {
            return "6.0"
        }
        if compilerVersion >= SwiftLanguageVersion(major: 5, minor: 9) {
            return "5.9"
        }
        return "5.6"
    }

    var codeGenTargetSwiftVersion: SwiftLanguageVersion {
        if compilerVersion >= SwiftLanguageVersion(major: 6, minor: 0) {
            return SwiftLanguageVersion(major: 6, minor: 0)
        }
        if compilerVersion >= SwiftLanguageVersion(major: 5, minor: 9) {
            return SwiftLanguageVersion(major: 5, minor: 9)
        }
        return SwiftLanguageVersion(major: 5, minor: 6)
    }

    var codeGenTargetSwiftVersionString: String {
        "\(codeGenTargetSwiftVersion.major).\(codeGenTargetSwiftVersion.minor)"
    }

    var asyncThrowsClause: String {
        codeGenTargetSwiftVersion >= SwiftLanguageVersion(major: 6, minor: 0) ? "throws(any Error)" : "throws"
    }

    private static func detectCompilerVersion() -> SwiftLanguageVersion {
        if let parsed = parseVersion(from: swiftVersionOutput()) {
            return parsed
        }

        #if swift(>=6.0)
        return SwiftLanguageVersion(major: 6, minor: 0)
        #elseif swift(>=5.9)
        return SwiftLanguageVersion(major: 5, minor: 9)
        #elseif swift(>=5.6)
        return SwiftLanguageVersion(major: 5, minor: 6)
        #else
        return SwiftLanguageVersion(major: 5, minor: 4)
        #endif
    }

    private static func swiftVersionOutput() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "--version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: outputData, encoding: .utf8)
    }

    private static func parseVersion(from output: String?) -> SwiftLanguageVersion? {
        guard let output = output else {
            return nil
        }

        let pattern = #"Swift version ([0-9]+)\.([0-9]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        guard let match = regex.firstMatch(in: output, range: range),
              let majorRange = Range(match.range(at: 1), in: output),
              let minorRange = Range(match.range(at: 2), in: output),
              let major = Int(output[majorRange]),
              let minor = Int(output[minorRange])
        else {
            return nil
        }

        return SwiftLanguageVersion(major: major, minor: minor)
    }
}
