import SwiftSOAPXML
import XCTest

final class XMLNamespaceResolverTests: XCTestCase {
    func test_resolveElementName_withDefaultNamespace_resolvesNamespaceURI() throws {
        var resolver = XMLNamespaceResolver()
        try resolver.push(declarations: [XMLNamespaceDeclaration(uri: "urn:default")])

        let resolved = try resolver.resolveElementName(
            XMLQualifiedName(localName: "Root")
        )

        XCTAssertEqual(resolved.localName, "Root")
        XCTAssertEqual(resolved.namespaceURI, "urn:default")
        XCTAssertNil(resolved.prefix)
    }

    func test_resolveElementName_withExplicitPrefix_resolvesNamespaceURI() throws {
        var resolver = XMLNamespaceResolver()
        try resolver.push(declarations: [XMLNamespaceDeclaration(prefix: "m", uri: "urn:messages")])

        let resolved = try resolver.resolveElementName(
            XMLQualifiedName(localName: "Echo", prefix: "m")
        )

        XCTAssertEqual(resolved.localName, "Echo")
        XCTAssertEqual(resolved.namespaceURI, "urn:messages")
        XCTAssertEqual(resolved.prefix, "m")
    }

    func test_resolveElementName_withUndefinedPrefix_throws() throws {
        let resolver = XMLNamespaceResolver()

        XCTAssertThrowsError(
            try resolver.resolveElementName(XMLQualifiedName(localName: "Echo", prefix: "m"))
        ) { error in
            guard case XMLNamespaceResolutionError.undefinedPrefix(prefix: "m", localName: "Echo") = error else {
                return XCTFail("Expected undefinedPrefix error, got: \(error)")
            }
        }
    }

    func test_resolveElementName_withRequiredDefaultNamespaceButNoBinding_throws() throws {
        let resolver = XMLNamespaceResolver()

        XCTAssertThrowsError(
            try resolver.resolveElementName(XMLQualifiedName(localName: "Root", namespaceURI: "urn:default"))
        ) { error in
            guard case XMLNamespaceResolutionError.missingDefaultNamespaceBinding(
                localName: "Root",
                requiredURI: "urn:default"
            ) = error else {
                return XCTFail("Expected missingDefaultNamespaceBinding error, got: \(error)")
            }
        }
    }

    func test_resolveEquivalentPrefixVariants_mapsToSameNamespaceURI() throws {
        var resolverA = XMLNamespaceResolver()
        try resolverA.push(declarations: [XMLNamespaceDeclaration(prefix: "a", uri: "urn:messages")])

        var resolverB = XMLNamespaceResolver()
        try resolverB.push(declarations: [XMLNamespaceDeclaration(prefix: "b", uri: "urn:messages")])

        let resolvedA = try resolverA.resolveElementName(XMLQualifiedName(localName: "Echo", prefix: "a"))
        let resolvedB = try resolverB.resolveElementName(XMLQualifiedName(localName: "Echo", prefix: "b"))

        XCTAssertEqual(resolvedA.localName, resolvedB.localName)
        XCTAssertEqual(resolvedA.namespaceURI, resolvedB.namespaceURI)
    }

    func test_deterministicPrefix_prefersLexicographicallySmallestPrefix() throws {
        var resolver = XMLNamespaceResolver()
        try resolver.push(declarations: [
            XMLNamespaceDeclaration(prefix: "z", uri: "urn:messages"),
            XMLNamespaceDeclaration(prefix: "a", uri: "urn:messages")
        ])

        let prefix = resolver.deterministicPrefix(forNamespaceURI: "urn:messages")

        XCTAssertEqual(prefix, "a")
    }

    func test_writer_namespaceValidation_missingDeclaration_throwsDeterministicError() {
        let writer = XMLTreeWriter()
        let tree = XMLTreeDocument(
            root: XMLTreeElement(
                name: XMLQualifiedName(localName: "Envelope", namespaceURI: "urn:messages", prefix: "m")
            )
        )

        XCTAssertThrowsError(try writer.writeDocument(tree)) { error in
            guard case XMLParsingError.parseFailed(let message) = error else {
                return XCTFail("Expected parseFailed, got: \(error)")
            }
            XCTAssertTrue(message?.contains("[XML6_3_NAMESPACE_VALIDATION]") == true)
        }
    }

    func test_writer_strictPolicy_missingDefaultNamespaceDeclaration_throwsDeterministicError() {
        let writer = XMLTreeWriter(
            configuration: .init(namespaceValidationMode: .strict)
        )
        let tree = XMLTreeDocument(
            root: XMLTreeElement(
                name: XMLQualifiedName(localName: "Envelope", namespaceURI: "urn:messages")
            )
        )

        XCTAssertThrowsError(try writer.writeDocument(tree)) { error in
            guard case XMLParsingError.parseFailed(let message) = error else {
                return XCTFail("Expected parseFailed, got: \(error)")
            }
            XCTAssertTrue(message?.contains("[XML6_3_NAMESPACE_VALIDATION]") == true)
        }
    }

    func test_writer_synthesizePolicy_allowsMissingDefaultNamespaceDeclaration() throws {
        let writer = XMLTreeWriter(
            configuration: .init(namespaceValidationMode: .synthesizeMissingDeclarations)
        )
        let parser = XMLTreeParser()
        let tree = XMLTreeDocument(
            root: XMLTreeElement(
                name: XMLQualifiedName(localName: "Envelope", namespaceURI: "urn:messages")
            )
        )

        let data = try writer.writeData(tree)
        let roundtripped = try parser.parse(data: data)

        XCTAssertEqual(roundtripped.root.name.localName, "Envelope")
        XCTAssertEqual(roundtripped.root.name.namespaceURI, "urn:messages")
        XCTAssertNil(roundtripped.root.name.prefix)
    }
}
