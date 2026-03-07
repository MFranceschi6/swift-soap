import Foundation
import SwiftSOAPCompatibility
import SwiftSOAPXMLCShim

public struct XMLTreeParser: Sendable {
    public struct Configuration: Sendable, Hashable {
        public let preserveWhitespaceTextNodes: Bool

        public init(preserveWhitespaceTextNodes: Bool = false) {
            self.preserveWhitespaceTextNodes = preserveWhitespaceTextNodes
        }
    }

    public let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    #if swift(>=6.0)
    public func parse(data: Data) throws(XMLParsingError) -> XMLTreeDocument {
        let document = try XMLDocument(data: data)
        return try parse(document: document)
    }

    public func parse(document: XMLDocument) throws(XMLParsingError) -> XMLTreeDocument {
        do {
            return try parseDocument(document)
        } catch let error as XMLParsingError {
            throw error
        } catch {
            throw XMLParsingError.other(underlyingError: error, message: "Unexpected XML tree parse error.")
        }
    }
    #else
    public func parse(data: Data) throws -> XMLTreeDocument {
        let document = try XMLDocument(data: data)
        return try parse(document: document)
    }

    public func parse(document: XMLDocument) throws -> XMLTreeDocument {
        try parseDocument(document)
    }
    #endif

    private func parseDocument(_ document: XMLDocument) throws -> XMLTreeDocument {
        guard let rootNode = document.rootElement() else {
            throw XMLParsingError.parseFailed(message: "XML document does not contain a root element.")
        }

        let rootElement = try parseElement(nodePointer: rootNode.nodePointer, sourceOrder: 0)
        let metadata = parseDocumentMetadata(from: rootNode.nodePointer.pointee.doc)
        return XMLTreeDocument(root: rootElement, metadata: metadata)
    }

    private func parseElement(nodePointer: xmlNodePtr, sourceOrder: Int?) throws -> XMLTreeElement {
        let nodeName = string(fromXMLCharPointer: nodePointer.pointee.name)
        guard let nodeName, nodeName.isEmpty == false else {
            throw XMLParsingError.nodeCreationFailed(name: "<unknown>", message: "XML element name is missing.")
        }

        let namespaceURI = string(fromXMLCharPointer: nodePointer.pointee.ns?.pointee.href)
        let prefix = string(fromXMLCharPointer: nodePointer.pointee.ns?.pointee.prefix)
        let qualifiedName = XMLQualifiedName(localName: nodeName, namespaceURI: namespaceURI, prefix: prefix)

        let attributes = parseAttributes(nodePointer: nodePointer)
        let namespaceDeclarations = parseNamespaceDeclarations(nodePointer: nodePointer)
        let children = try parseChildren(nodePointer: nodePointer)
        let metadata = XMLNodeStructuralMetadata(
            sourceOrder: sourceOrder,
            originalPrefix: prefix,
            wasSelfClosing: nil
        )

        return XMLTreeElement(
            name: qualifiedName,
            attributes: attributes,
            namespaceDeclarations: namespaceDeclarations,
            children: children,
            metadata: metadata
        )
    }

    private func parseAttributes(nodePointer: xmlNodePtr) -> [XMLTreeAttribute] {
        var attributes: [XMLTreeAttribute] = []
        var attributePointer = nodePointer.pointee.properties

        while let currentAttributePointer = attributePointer {
            let localName = string(fromXMLCharPointer: currentAttributePointer.pointee.name) ?? ""
            let namespaceURI = string(fromXMLCharPointer: currentAttributePointer.pointee.ns?.pointee.href)
            let prefix = string(fromXMLCharPointer: currentAttributePointer.pointee.ns?.pointee.prefix)
            let name = XMLQualifiedName(localName: localName, namespaceURI: namespaceURI, prefix: prefix)
            let value = parseAttributeValue(attributePointer: currentAttributePointer, nodePointer: nodePointer)

            attributes.append(XMLTreeAttribute(name: name, value: value))
            attributePointer = currentAttributePointer.pointee.next
        }

        return attributes
    }

    private func parseAttributeValue(attributePointer: xmlAttrPtr, nodePointer: xmlNodePtr) -> String {
        guard let documentPointer = nodePointer.pointee.doc else {
            return ""
        }

        guard let valuePointer = xmlNodeListGetString(documentPointer, attributePointer.pointee.children, 1) else {
            return ""
        }

        return LibXML2.withOwnedXMLCharPointer(valuePointer) { ownedValuePointer in
            String(cString: UnsafePointer<CChar>(OpaquePointer(ownedValuePointer)))
        } ?? ""
    }

    private func parseNamespaceDeclarations(nodePointer: xmlNodePtr) -> [XMLNamespaceDeclaration] {
        var declarations: [XMLNamespaceDeclaration] = []
        var namespacePointer = nodePointer.pointee.nsDef

        while let currentNamespacePointer = namespacePointer {
            let prefix = string(fromXMLCharPointer: currentNamespacePointer.pointee.prefix)
            let uri = string(fromXMLCharPointer: currentNamespacePointer.pointee.href) ?? ""
            declarations.append(XMLNamespaceDeclaration(prefix: prefix, uri: uri))
            namespacePointer = currentNamespacePointer.pointee.next
        }

        return declarations
    }

    private func parseChildren(nodePointer: xmlNodePtr) throws -> [XMLTreeNode] {
        var children: [XMLTreeNode] = []
        var childPointer = nodePointer.pointee.children
        var sourceOrder = 0

        while let currentChildPointer = childPointer {
            defer {
                childPointer = currentChildPointer.pointee.next
                sourceOrder += 1
            }

            switch currentChildPointer.pointee.type {
            case XML_ELEMENT_NODE:
                let element = try parseElement(nodePointer: currentChildPointer, sourceOrder: sourceOrder)
                children.append(.element(element))
            case XML_TEXT_NODE:
                let value = string(fromNodeContent: currentChildPointer)
                if shouldKeepTextNode(value) {
                    children.append(.text(value))
                }
            case XML_CDATA_SECTION_NODE:
                children.append(.cdata(string(fromNodeContent: currentChildPointer)))
            case XML_COMMENT_NODE:
                children.append(.comment(string(fromNodeContent: currentChildPointer)))
            default:
                break
            }
        }

        return children
    }

    private func parseDocumentMetadata(from documentPointer: xmlDocPtr?) -> XMLDocumentStructuralMetadata {
        let xmlVersion = string(fromXMLCharPointer: documentPointer?.pointee.version)
        let encoding = string(fromXMLCharPointer: documentPointer?.pointee.encoding)
        let standaloneValue = Int32(documentPointer?.pointee.standalone ?? -1)
        let standalone: Bool?
        if standaloneValue < 0 {
            standalone = nil
        } else {
            standalone = standaloneValue == 1
        }

        return XMLDocumentStructuralMetadata(
            xmlVersion: xmlVersion,
            encoding: encoding,
            standalone: standalone,
            canonicalization: XMLCanonicalizationMetadata()
        )
    }

    private func string(fromNodeContent nodePointer: xmlNodePtr) -> String {
        guard let contentPointer = nodePointer.pointee.content else {
            return ""
        }
        return String(cString: UnsafePointer<CChar>(OpaquePointer(contentPointer)))
    }

    private func shouldKeepTextNode(_ value: String) -> Bool {
        if configuration.preserveWhitespaceTextNodes {
            return true
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func string(fromXMLCharPointer pointer: UnsafePointer<xmlChar>?) -> String? {
        guard let pointer else {
            return nil
        }
        return String(cString: UnsafePointer<CChar>(OpaquePointer(pointer)))
    }
}
