import Foundation
import XCTest

final class PluginManifestContractTests: XCTestCase {
    func test_modernManifests_defineBuildToolPlugin() throws {
        let fileManager = FileManager.default
        let rootPath = fileManager.currentDirectoryPath

        let manifest56 = URL(fileURLWithPath: rootPath).appendingPathComponent("Package@swift-5.6.swift")
        let manifest59 = URL(fileURLWithPath: rootPath).appendingPathComponent("Package@swift-5.9.swift")
        let manifest60 = URL(fileURLWithPath: rootPath).appendingPathComponent("Package@swift-6.0.swift")
        let manifest61 = URL(fileURLWithPath: rootPath).appendingPathComponent("Package@swift-6.1.swift")

        let manifest56Content = try String(contentsOf: manifest56, encoding: .utf8)
        let manifest59Content = try String(contentsOf: manifest59, encoding: .utf8)
        let manifest60Content = try String(contentsOf: manifest60, encoding: .utf8)
        let manifest61Content = try String(contentsOf: manifest61, encoding: .utf8)

        XCTAssertTrue(manifest56Content.contains(".plugin("))
        XCTAssertTrue(manifest56Content.contains("SwiftSOAPCodeGenPlugin"))
        XCTAssertTrue(manifest56Content.contains(".plugin(name: \"SwiftSOAPCodeGenPlugin\", targets: [\"SwiftSOAPCodeGenPlugin\"])"))
        XCTAssertTrue(manifest59Content.contains(".plugin("))
        XCTAssertTrue(manifest59Content.contains("SwiftSOAPCodeGenPlugin"))
        XCTAssertTrue(manifest59Content.contains(".plugin(name: \"SwiftSOAPCodeGenPlugin\", targets: [\"SwiftSOAPCodeGenPlugin\"])"))
        XCTAssertTrue(manifest59Content.contains(".library(name: \"SwiftSOAPXMLMacros\", targets: [\"SwiftSOAPXMLMacros\"])"))
        XCTAssertTrue(manifest59Content.contains(".macro("))
        XCTAssertTrue(manifest60Content.contains(".plugin("))
        XCTAssertTrue(manifest60Content.contains("SwiftSOAPCodeGenPlugin"))
        XCTAssertTrue(manifest60Content.contains(".plugin(name: \"SwiftSOAPCodeGenPlugin\", targets: [\"SwiftSOAPCodeGenPlugin\"])"))
        XCTAssertTrue(manifest60Content.contains(".library(name: \"SwiftSOAPXMLMacros\", targets: [\"SwiftSOAPXMLMacros\"])"))
        XCTAssertTrue(manifest60Content.contains(".macro("))
        XCTAssertTrue(manifest61Content.contains(".plugin("))
        XCTAssertTrue(manifest61Content.contains("SwiftSOAPCodeGenPlugin"))
        XCTAssertTrue(manifest61Content.contains(".plugin(name: \"SwiftSOAPCodeGenPlugin\", targets: [\"SwiftSOAPCodeGenPlugin\"])"))
        XCTAssertTrue(manifest61Content.contains(".library(name: \"SwiftSOAPXMLMacros\", targets: [\"SwiftSOAPXMLMacros\"])"))
        XCTAssertTrue(manifest61Content.contains(".macro("))
        XCTAssertTrue(manifest61Content.contains("path: \"Plugins/SwiftSOAPCodeGenPlugin61\""))
    }

    func test_package61Plugin_usesURLBasedAPIs() throws {
        let fileManager = FileManager.default
        let rootPath = fileManager.currentDirectoryPath
        let pluginPath = URL(fileURLWithPath: rootPath)
            .appendingPathComponent("Plugins/SwiftSOAPCodeGenPlugin61/Plugin.swift")

        let pluginContent = try String(contentsOf: pluginPath, encoding: .utf8)

        XCTAssertTrue(pluginContent.contains("directoryURL"))
        XCTAssertTrue(pluginContent.contains("pluginWorkDirectoryURL"))
        XCTAssertTrue(pluginContent.contains("codeGeneratorTool.url"))
    }
}
