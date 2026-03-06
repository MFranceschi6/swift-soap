@preconcurrency import CLibXML2
import Foundation
import Logging

public struct XMLDocument: Sendable {
    private final class Storage: @unchecked Sendable {
        var documentPointer: xmlDocPtr?

        init(documentPointer: xmlDocPtr?) {
            self.documentPointer = documentPointer
        }

        deinit {
            if let documentPointer = documentPointer {
                xmlFreeDoc(documentPointer)
            }
        }
    }

    private let storage: Storage
    private let logger: Logger

    public init(rootElementName: String, logger: Logger? = nil) throws {
        try self.init(createDocument: rootElementName, rootNamespace: nil, logger: logger ?? Self.defaultLogger())
    }

    public init(rootElementName: String, rootNamespace: XMLNamespace, logger: Logger? = nil) throws {
        try self.init(
            createDocument: rootElementName,
            rootNamespace: rootNamespace as XMLNamespace?,
            logger: logger ?? Self.defaultLogger()
        )
    }

    public init(data: Data, logger: Logger? = nil) throws {
        try self.init(parseDocument: data, sourceURL: nil, logger: logger ?? Self.defaultLogger())
    }

    public init(data: Data, sourceURL: URL, logger: Logger? = nil) throws {
        try self.init(parseDocument: data, sourceURL: sourceURL, logger: logger ?? Self.defaultLogger())
    }

    public init(url: URL, logger: Logger? = nil) throws {
        let effectiveLogger: Logger = logger ?? Self.defaultLogger()

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw XMLParsingError.other(
                underlyingError: error,
                message: "Unable to load XML data from URL '\(url.absoluteString)'."
            )
        }
        try self.init(parseDocument: data, sourceURL: url, logger: effectiveLogger)
    }

    private init(createDocument rootElementName: String, rootNamespace: XMLNamespace?, logger: Logger) throws {
        LibXML2.ensureInitialized()

        self.logger = logger

        let documentPointer = LibXML2.withXMLCharPointer("1.0") { versionPointer in
            xmlNewDoc(versionPointer)
        }
        guard let documentPointer = documentPointer else {
            throw XMLParsingError.documentCreationFailed(message: "Unable to allocate XML document.")
        }

        guard let rootElement = try XMLDocument.makeNode(named: rootElementName, namespace: rootNamespace) else {
            xmlFreeDoc(documentPointer)
            throw XMLParsingError.nodeCreationFailed(name: rootElementName, message: "Unable to create root element.")
        }

        xmlDocSetRootElement(documentPointer, rootElement)
        self.storage = Storage(documentPointer: documentPointer)
    }

    private init(parseDocument data: Data, sourceURL: URL?, logger: Logger) throws {
        LibXML2.ensureInitialized()

        self.logger = logger

        let options = Int32(XML_PARSE_NOBLANKS.rawValue)

        let documentPointer: xmlDocPtr? = data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return nil
            }

            // libxml2 expects a C char buffer; we pass bytes and length.
            let bufferPointer = baseAddress.assumingMemoryBound(to: CChar.self)

            if let sourceURL = sourceURL {
                return sourceURL.absoluteString.withCString { urlCString in
                    xmlReadMemory(bufferPointer, Int32(rawBuffer.count), urlCString, nil, options)
                }
            } else {
                return xmlReadMemory(bufferPointer, Int32(rawBuffer.count), nil, nil, options)
            }
        }

        guard let documentPointer = documentPointer else {
            // Best-effort: attempt to read libxml2's last error.
            let lastErrorPointer = xmlGetLastError()
            let message: String?
            if let lastErrorPointer = lastErrorPointer, let errorMessagePointer = lastErrorPointer.pointee.message {
                message = String(cString: errorMessagePointer).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                message = nil
            }

            logger.debug("XML parse failed", metadata: [
                "byteCount": "\(data.count)"
            ])
            throw XMLParsingError.parseFailed(message: message)
        }

        self.storage = Storage(documentPointer: documentPointer)
    }

    public func rootElement() -> XMLNode? {
        guard let documentPointer = storage.documentPointer else {
            return nil
        }
        guard let nodePointer = xmlDocGetRootElement(documentPointer) else {
            return nil
        }
        return XMLNode(nodePointer: nodePointer)
    }

    public func xpathFirstNode(
        _ expression: String,
        namespaces: [String: String] = [:]
    ) throws -> XMLNode? {
        guard let documentPointer = storage.documentPointer else {
            return nil
        }

        logger.trace("Evaluating XPath expression", metadata: [
            "expression": "\(expression)"
        ])

        let contextPointer = xmlXPathNewContext(documentPointer)
        guard let contextPointer = contextPointer else {
            throw XMLParsingError.xpathFailed(expression: expression, message: "Unable to create XPath context.")
        }
        defer { xmlXPathFreeContext(contextPointer) }

        try registerNamespaces(namespaces, expression: expression, contextPointer: contextPointer)

        let resultPointer = LibXML2.withXMLCharPointer(expression) { expressionPointer in
            xmlXPathEvalExpression(expressionPointer, contextPointer)
        }
        guard let resultPointer = resultPointer else {
            let lastErrorPointer = xmlGetLastError()
            let message: String?
            if let lastErrorPointer = lastErrorPointer, let errorMessagePointer = lastErrorPointer.pointee.message {
                message = String(cString: errorMessagePointer).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                message = nil
            }
            throw XMLParsingError.xpathFailed(expression: expression, message: message)
        }
        defer { xmlXPathFreeObject(resultPointer) }

        guard let nodeSetPointer = resultPointer.pointee.nodesetval else {
            return nil
        }

        let nodeCount = Int(nodeSetPointer.pointee.nodeNr)
        guard nodeCount > 0 else {
            return nil
        }

        guard let nodePointer = nodeSetPointer.pointee.nodeTab[0] else {
            return nil
        }

        return XMLNode(nodePointer: nodePointer)
    }

    public func xpathNodes(
        _ expression: String,
        namespaces: [String: String] = [:]
    ) throws -> [XMLNode] {
        guard let documentPointer = storage.documentPointer else {
            return []
        }

        let contextPointer = xmlXPathNewContext(documentPointer)
        guard let contextPointer = contextPointer else {
            throw XMLParsingError.xpathFailed(expression: expression, message: "Unable to create XPath context.")
        }
        defer { xmlXPathFreeContext(contextPointer) }

        try registerNamespaces(namespaces, expression: expression, contextPointer: contextPointer)

        let resultPointer = LibXML2.withXMLCharPointer(expression) { expressionPointer in
            xmlXPathEvalExpression(expressionPointer, contextPointer)
        }
        guard let resultPointer = resultPointer else {
            let lastErrorPointer = xmlGetLastError()
            let message: String?
            if let lastErrorPointer = lastErrorPointer, let errorMessagePointer = lastErrorPointer.pointee.message {
                message = String(cString: errorMessagePointer).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                message = nil
            }
            throw XMLParsingError.xpathFailed(expression: expression, message: message)
        }
        defer { xmlXPathFreeObject(resultPointer) }

        guard let nodeSetPointer = resultPointer.pointee.nodesetval else {
            return []
        }

        let nodeCount = Int(nodeSetPointer.pointee.nodeNr)
        guard nodeCount > 0 else {
            return []
        }

        return (0..<nodeCount).compactMap { index in
            guard let nodePointer = nodeSetPointer.pointee.nodeTab[index] else {
                return nil
            }
            return XMLNode(nodePointer: nodePointer)
        }
    }

    public func serializedData(encoding: String = "UTF-8", prettyPrinted: Bool = false) throws -> Data {
        guard let documentPointer = storage.documentPointer else {
            return Data()
        }

        var bufferPointer: UnsafeMutablePointer<xmlChar>?
        var size: Int32 = 0
        let format: Int32 = prettyPrinted ? 1 : 0

        encoding.withCString { encodingCString in
            xmlDocDumpFormatMemoryEnc(documentPointer, &bufferPointer, &size, encodingCString, format)
        }

        guard let bufferPointer = bufferPointer, size >= 0 else {
            let lastErrorPointer = xmlGetLastError()
            let message: String?
            if let lastErrorPointer = lastErrorPointer, let errorMessagePointer = lastErrorPointer.pointee.message {
                message = String(cString: errorMessagePointer).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                message = nil
            }
            throw XMLParsingError.other(underlyingError: nil, message: message ?? "XML serialization failed.")
        }

        defer { xmlFree(bufferPointer) }
        return Data(bytes: bufferPointer, count: Int(size))
    }

    public func createElement(named name: String, namespace: XMLNamespace? = nil) throws -> XMLNode {
        guard let nodePointer = try XMLDocument.makeNode(named: name, namespace: namespace) else {
            throw XMLParsingError.nodeCreationFailed(name: name, message: "Unable to create XML element.")
        }
        return XMLNode(nodePointer: nodePointer)
    }

    public func appendChild(_ child: XMLNode, to parent: XMLNode) throws {
        try parent.addChild(child)
    }

    private func registerNamespaces(
        _ namespaces: [String: String],
        expression: String,
        contextPointer: xmlXPathContextPtr
    ) throws {
        for (prefix, uri) in namespaces {
            try LibXML2.withXMLCharPointer(prefix) { prefixPointer in
                try LibXML2.withXMLCharPointer(uri) { uriPointer in
                    let result = xmlXPathRegisterNs(contextPointer, prefixPointer, uriPointer)
                    if result != 0 {
                        throw XMLParsingError.xpathFailed(
                            expression: expression,
                            message: "Unable to register namespace prefix '\(prefix)'."
                        )
                    }
                }
            }
        }
    }

    private static func makeNode(named name: String, namespace: XMLNamespace?) throws -> xmlNodePtr? {
        let nodePointer = LibXML2.withXMLCharPointer(name) { namePointer in
            xmlNewNode(nil, namePointer)
        }

        guard let nodePointer = nodePointer else {
            return nil
        }

        if let namespace = namespace {
            if namespace.prefix != nil && namespace.uri.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                xmlFreeNode(nodePointer)
                throw XMLParsingError.invalidNamespaceConfiguration(prefix: namespace.prefix, uri: namespace.uri)
            }

            let namespacePointer = LibXML2.withXMLCharPointer(namespace.uri) { uriPointer -> xmlNsPtr? in
                if let prefix = namespace.prefix {
                    return LibXML2.withXMLCharPointer(prefix) { prefixPointer in
                        xmlNewNs(nodePointer, uriPointer, prefixPointer)
                    }
                } else {
                    return xmlNewNs(nodePointer, uriPointer, nil)
                }
            }

            guard let namespacePointer = namespacePointer else {
                xmlFreeNode(nodePointer)
                throw XMLParsingError.nodeOperationFailed(
                    message: "Unable to assign namespace '\(namespace.uri)' to element '\(name)'."
                )
            }

            xmlSetNs(nodePointer, namespacePointer)
        }

        return nodePointer
    }

    private static func defaultLogger() -> Logger {
        Logger(label: "org.swift.soap.SwiftSOAPXML")
    }
}
