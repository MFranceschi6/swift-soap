import Foundation
import SwiftSOAPCompatibility
import SwiftSOAPXMLCShim

public struct XMLTreeWriter: Sendable {
    public enum NamespaceValidationMode: Sendable, Hashable {
        case strict
        case synthesizeMissingDeclarations

        fileprivate var validatorMode: XMLNamespaceValidator.Mode {
            switch self {
            case .strict:
                return .strict
            case .synthesizeMissingDeclarations:
                return .synthesizeMissingDeclarations
            }
        }
    }

    public struct Limits: Sendable, Hashable {
        public let maxDepth: Int
        public let maxNodeCount: Int?
        public let maxOutputBytes: Int?
        public let maxTextNodeBytes: Int?
        public let maxCDATABlockBytes: Int?
        public let maxCommentBytes: Int?

        public init(
            maxDepth: Int = 4096,
            maxNodeCount: Int? = nil,
            maxOutputBytes: Int? = nil,
            maxTextNodeBytes: Int? = nil,
            maxCDATABlockBytes: Int? = nil,
            maxCommentBytes: Int? = nil
        ) {
            self.maxDepth = max(1, maxDepth)
            self.maxNodeCount = maxNodeCount
            self.maxOutputBytes = maxOutputBytes
            self.maxTextNodeBytes = maxTextNodeBytes
            self.maxCDATABlockBytes = maxCDATABlockBytes
            self.maxCommentBytes = maxCommentBytes
        }

        public static func untrustedInputDefault() -> Limits {
            Limits(
                maxDepth: 256,
                maxNodeCount: 200_000,
                maxOutputBytes: 16 * 1024 * 1024,
                maxTextNodeBytes: 1 * 1024 * 1024,
                maxCDATABlockBytes: 4 * 1024 * 1024,
                maxCommentBytes: 256 * 1024
            )
        }
    }

    public struct Configuration: Sendable, Hashable {
        public let encoding: String
        public let prettyPrinted: Bool
        public let namespaceValidationMode: NamespaceValidationMode
        public let limits: Limits

        public init(
            encoding: String = "UTF-8",
            prettyPrinted: Bool = false,
            namespaceValidationMode: NamespaceValidationMode = .strict,
            limits: Limits = Limits()
        ) {
            self.encoding = encoding
            self.prettyPrinted = prettyPrinted
            self.namespaceValidationMode = namespaceValidationMode
            self.limits = limits
        }

        public static func untrustedInputProfile(
            encoding: String = "UTF-8",
            prettyPrinted: Bool = false
        ) -> Configuration {
            Configuration(
                encoding: encoding,
                prettyPrinted: prettyPrinted,
                namespaceValidationMode: .strict,
                limits: .untrustedInputDefault()
            )
        }
    }

    private struct WriteState {
        var nodeCount: Int = 0
    }

    public let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    #if swift(>=6.0)
    public func writeDocument(_ treeDocument: XMLTreeDocument) throws(XMLParsingError) -> XMLDocument {
        do {
            return try writeDocumentImpl(treeDocument)
        } catch let error as XMLParsingError {
            throw error
        } catch {
            throw XMLParsingError.other(underlyingError: error, message: "Unexpected XML tree writer error.")
        }
    }

    public func writeData(_ treeDocument: XMLTreeDocument) throws(XMLParsingError) -> Data {
        do {
            let xmlDocument = try writeDocument(treeDocument)
            let xmlData = try xmlDocument.serializedData(
                encoding: configuration.encoding,
                prettyPrinted: configuration.prettyPrinted
            )
            try ensureLimit(
                actual: xmlData.count,
                limit: configuration.limits.maxOutputBytes,
                code: "XML6_2H_MAX_OUTPUT_BYTES",
                context: "serialized XML output bytes"
            )
            return xmlData
        } catch let error as XMLParsingError {
            throw error
        } catch {
            throw XMLParsingError.other(underlyingError: error, message: "Unexpected XML tree writer error.")
        }
    }
    #else
    public func writeDocument(_ treeDocument: XMLTreeDocument) throws -> XMLDocument {
        try writeDocumentImpl(treeDocument)
    }

    public func writeData(_ treeDocument: XMLTreeDocument) throws -> Data {
        let xmlDocument = try writeDocument(treeDocument)
        let xmlData = try xmlDocument.serializedData(
            encoding: configuration.encoding,
            prettyPrinted: configuration.prettyPrinted
        )
        try ensureLimit(
            actual: xmlData.count,
            limit: configuration.limits.maxOutputBytes,
            code: "XML6_2H_MAX_OUTPUT_BYTES",
            context: "serialized XML output bytes"
        )
        return xmlData
    }
    #endif

    private func writeDocumentImpl(_ treeDocument: XMLTreeDocument) throws -> XMLDocument {
        do {
            try XMLNamespaceValidator.validate(
                document: treeDocument,
                mode: configuration.namespaceValidationMode.validatorMode
            )
        } catch let resolutionError as XMLNamespaceResolutionError {
            throw XMLParsingError.parseFailed(
                message: "[XML6_3_NAMESPACE_VALIDATION] Namespace validation failed: \(resolutionError)."
            )
        }

        let root = treeDocument.root
        let rootNamespace = makeNamespace(from: root.name)

        let xmlDocument: XMLDocument
        if let rootNamespace {
            xmlDocument = try XMLDocument(rootElementName: root.name.localName, rootNamespace: rootNamespace)
        } else {
            xmlDocument = try XMLDocument(rootElementName: root.name.localName)
        }

        guard let rootNode = xmlDocument.rootElement() else {
            throw XMLParsingError.documentCreationFailed(message: "Unable to create root element in XML document.")
        }

        var writeState = WriteState()
        try writeElementContent(
            root,
            into: rootNode,
            in: xmlDocument,
            depth: 1,
            writeState: &writeState
        )
        return xmlDocument
    }

    private func writeElementContent(
        _ element: XMLTreeElement,
        into node: XMLNode,
        in document: XMLDocument,
        depth: Int,
        writeState: inout WriteState
    ) throws {
        try ensureDepth(depth)
        try incrementNodeCount(writeState: &writeState, context: "element")

        try applyNamespaceDeclarations(element.namespaceDeclarations, to: node)
        try applyAttributes(element.attributes, to: node)

        for child in element.children {
            switch child {
            case .element(let childElement):
                let namespace = makeNamespace(from: childElement.name)
                let childNode = try document.createElement(
                    named: childElement.name.localName,
                    namespace: namespace
                )
                try document.appendChild(childNode, to: node)
                try writeElementContent(
                    childElement,
                    into: childNode,
                    in: document,
                    depth: depth + 1,
                    writeState: &writeState
                )
            case .text(let value):
                try ensureUTF8Length(
                    value,
                    limit: configuration.limits.maxTextNodeBytes,
                    code: "XML6_2H_MAX_TEXT_NODE_BYTES",
                    context: "text node"
                )
                try incrementNodeCount(writeState: &writeState, context: "text node")
                try appendTextNode(value, to: node)
            case .cdata(let value):
                try ensureUTF8Length(
                    value,
                    limit: configuration.limits.maxCDATABlockBytes,
                    code: "XML6_2H_MAX_CDATA_BYTES",
                    context: "CDATA node"
                )
                try incrementNodeCount(writeState: &writeState, context: "CDATA node")
                try appendCDATASection(value, to: node)
            case .comment(let value):
                try ensureUTF8Length(
                    value,
                    limit: configuration.limits.maxCommentBytes,
                    code: "XML6_2H_MAX_COMMENT_BYTES",
                    context: "comment node"
                )
                try incrementNodeCount(writeState: &writeState, context: "comment node")
                try appendComment(value, to: node)
            }
        }
    }

    private func makeNamespace(from qualifiedName: XMLQualifiedName) -> XMLNamespace? {
        guard let namespaceURI = qualifiedName.namespaceURI else {
            return nil
        }
        return XMLNamespace(prefix: qualifiedName.prefix, uri: namespaceURI)
    }

    private func applyNamespaceDeclarations(
        _ namespaceDeclarations: [XMLNamespaceDeclaration],
        to node: XMLNode
    ) throws {
        for declaration in namespaceDeclarations where shouldDeclareNamespace(declaration, on: node.nodePointer) {
            if declaration.prefix != nil && declaration.uri.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw XMLParsingError.invalidNamespaceConfiguration(prefix: declaration.prefix, uri: declaration.uri)
            }

            let namespacePointer = LibXML2.withXMLCharPointer(declaration.uri) { uriPointer -> xmlNsPtr? in
                if let prefix = declaration.prefix {
                    return LibXML2.withXMLCharPointer(prefix) { prefixPointer in
                        xmlNewNs(node.nodePointer, uriPointer, prefixPointer)
                    }
                }
                return xmlNewNs(node.nodePointer, uriPointer, nil)
            }

            guard namespacePointer != nil else {
                throw XMLParsingError.nodeOperationFailed(
                    message: "Unable to declare namespace '\(declaration.uri)' on '\(node.name ?? "<unknown>")'."
                )
            }
        }
    }

    private func applyAttributes(_ attributes: [XMLTreeAttribute], to node: XMLNode) throws {
        var generatedNamespaceIndex = 0

        for attribute in attributes {
            if let prefix = attribute.name.prefix, attribute.name.namespaceURI == nil {
                throw XMLParsingError.invalidNamespaceConfiguration(prefix: prefix, uri: nil)
            }

            let attributeNamespace = try resolveAttributeNamespace(
                for: attribute,
                on: node.nodePointer,
                generatedNamespaceIndex: &generatedNamespaceIndex
            )

            let setResult = LibXML2.withXMLCharPointer(attribute.name.localName) { attributeNamePointer in
                LibXML2.withXMLCharPointer(attribute.value) { valuePointer in
                    if let attributeNamespace {
                        return xmlSetNsProp(node.nodePointer, attributeNamespace, attributeNamePointer, valuePointer)
                    }
                    return xmlSetProp(node.nodePointer, attributeNamePointer, valuePointer)
                }
            }

            guard setResult != nil else {
                throw XMLParsingError.nodeOperationFailed(
                    message: "Unable to set attribute '\(attribute.name.qualifiedName)' on '\(node.name ?? "<unknown>")'."
                )
            }
        }
    }

    private func resolveAttributeNamespace(
        for attribute: XMLTreeAttribute,
        on nodePointer: xmlNodePtr,
        generatedNamespaceIndex: inout Int
    ) throws -> xmlNsPtr? {
        guard let namespaceURI = attribute.name.namespaceURI else {
            return nil
        }

        if let prefix = attribute.name.prefix {
            if let existing = lookupNamespace(prefix: prefix, uri: namespaceURI, nodePointer: nodePointer) {
                return existing
            }
            return try declareNamespace(prefix: prefix, uri: namespaceURI, on: nodePointer)
        }

        if let existing = lookupNamespaceByURI(uri: namespaceURI, nodePointer: nodePointer) {
            return existing
        }

        let generatedPrefix = makeGeneratedNamespacePrefix(
            for: nodePointer,
            startingAt: &generatedNamespaceIndex
        )
        return try declareNamespace(prefix: generatedPrefix, uri: namespaceURI, on: nodePointer)
    }

    private func lookupNamespace(prefix: String, uri: String, nodePointer: xmlNodePtr) -> xmlNsPtr? {
        guard let documentPointer = nodePointer.pointee.doc else {
            return nil
        }

        let namespaceByPrefix = LibXML2.withXMLCharPointer(prefix) { prefixPointer in
            xmlSearchNs(documentPointer, nodePointer, prefixPointer)
        }
        guard let namespaceByPrefix else {
            return nil
        }

        let namespaceURI = string(fromXMLCharPointer: namespaceByPrefix.pointee.href)
        return namespaceURI == uri ? namespaceByPrefix : nil
    }

    private func lookupNamespaceByURI(uri: String, nodePointer: xmlNodePtr) -> xmlNsPtr? {
        guard let documentPointer = nodePointer.pointee.doc else {
            return nil
        }
        return LibXML2.withXMLCharPointer(uri) { uriPointer in
            xmlSearchNsByHref(documentPointer, nodePointer, uriPointer)
        }
    }

    private func declareNamespace(prefix: String, uri: String, on nodePointer: xmlNodePtr) throws -> xmlNsPtr {
        let namespacePointer = LibXML2.withXMLCharPointer(uri) { uriPointer in
            LibXML2.withXMLCharPointer(prefix) { prefixPointer in
                xmlNewNs(nodePointer, uriPointer, prefixPointer)
            }
        }

        guard let namespacePointer else {
            throw XMLParsingError.nodeOperationFailed(
                message: "Unable to declare namespace '\(prefix):\(uri)'."
            )
        }
        return namespacePointer
    }

    private func makeGeneratedNamespacePrefix(
        for nodePointer: xmlNodePtr,
        startingAt index: inout Int
    ) -> String {
        while true {
            let candidate = "ns\(index)"
            index += 1

            let existing = LibXML2.withXMLCharPointer(candidate) { prefixPointer in
                xmlSearchNs(nodePointer.pointee.doc, nodePointer, prefixPointer)
            }
            if existing == nil {
                return candidate
            }
        }
    }

    private func shouldDeclareNamespace(_ declaration: XMLNamespaceDeclaration, on nodePointer: xmlNodePtr) -> Bool {
        var namespacePointer = nodePointer.pointee.nsDef
        while let currentNamespacePointer = namespacePointer {
            let existingPrefix = string(fromXMLCharPointer: currentNamespacePointer.pointee.prefix)
            let existingURI = string(fromXMLCharPointer: currentNamespacePointer.pointee.href)
            if existingPrefix == declaration.prefix && existingURI == declaration.uri {
                return false
            }
            namespacePointer = currentNamespacePointer.pointee.next
        }
        return true
    }

    private func appendTextNode(_ value: String, to node: XMLNode) throws {
        let textNodePointer = LibXML2.withXMLCharPointer(value) { valuePointer in
            xmlNewText(valuePointer)
        }
        guard let textNodePointer = textNodePointer else {
            throw XMLParsingError.nodeCreationFailed(name: "#text", message: "Unable to create text node.")
        }

        guard xmlAddChild(node.nodePointer, textNodePointer) != nil else {
            xmlFreeNode(textNodePointer)
            throw XMLParsingError.nodeOperationFailed(message: "Unable to append text node.")
        }
    }

    private func appendCDATASection(_ value: String, to node: XMLNode) throws {
        guard let documentPointer = node.nodePointer.pointee.doc else {
            throw XMLParsingError.nodeOperationFailed(message: "Unable to resolve XML document for CDATA section.")
        }

        let utf8Bytes = Array(value.utf8)
        let cdataLength = try XMLInteropBounds.checkedNonNegativeInt32Length(
            utf8Bytes.count,
            code: "XML6_2H_INT32_CDATA_LENGTH",
            context: "xmlNewCDataBlock input"
        )

        let cdataNodePointer = utf8Bytes.withUnsafeBufferPointer { buffer -> xmlNodePtr? in
            guard let baseAddress = buffer.baseAddress else {
                return xmlNewCDataBlock(documentPointer, nil, 0)
            }
            return xmlNewCDataBlock(
                documentPointer,
                UnsafePointer<xmlChar>(baseAddress),
                cdataLength
            )
        }

        guard let cdataNodePointer = cdataNodePointer else {
            throw XMLParsingError.nodeCreationFailed(
                name: "#cdata-section",
                message: "Unable to create CDATA section."
            )
        }

        guard xmlAddChild(node.nodePointer, cdataNodePointer) != nil else {
            xmlFreeNode(cdataNodePointer)
            throw XMLParsingError.nodeOperationFailed(message: "Unable to append CDATA section.")
        }
    }

    private func appendComment(_ value: String, to node: XMLNode) throws {
        let commentNodePointer = LibXML2.withXMLCharPointer(value) { valuePointer in
            xmlNewComment(valuePointer)
        }
        guard let commentNodePointer = commentNodePointer else {
            throw XMLParsingError.nodeCreationFailed(name: "#comment", message: "Unable to create XML comment.")
        }

        guard xmlAddChild(node.nodePointer, commentNodePointer) != nil else {
            xmlFreeNode(commentNodePointer)
            throw XMLParsingError.nodeOperationFailed(message: "Unable to append XML comment.")
        }
    }

    private func string(fromXMLCharPointer pointer: UnsafePointer<xmlChar>?) -> String? {
        guard let pointer else {
            return nil
        }
        return String(cString: UnsafePointer<CChar>(OpaquePointer(pointer)))
    }

    private func ensureDepth(_ depth: Int) throws {
        guard depth <= configuration.limits.maxDepth else {
            throw XMLParsingError.parseFailed(
                message: "[XML6_2H_MAX_DEPTH] XML depth exceeded max depth (\(configuration.limits.maxDepth)): \(depth)."
            )
        }
    }

    private func incrementNodeCount(writeState: inout WriteState, context: String) throws {
        writeState.nodeCount += 1
        try ensureLimit(
            actual: writeState.nodeCount,
            limit: configuration.limits.maxNodeCount,
            code: "XML6_2H_MAX_NODE_COUNT",
            context: "total written nodes after \(context)"
        )
    }

    private func ensureUTF8Length(
        _ value: String,
        limit: Int?,
        code: String,
        context: String
    ) throws {
        try ensureLimit(
            actual: value.utf8.count,
            limit: limit,
            code: code,
            context: context
        )
    }

    private func ensureLimit(
        actual: Int,
        limit: Int?,
        code: String,
        context: String
    ) throws {
        guard let limit else {
            return
        }

        guard actual <= limit else {
            throw XMLParsingError.parseFailed(
                message: "[\(code)] \(context) exceeded max (\(limit)): \(actual)."
            )
        }
    }
}
