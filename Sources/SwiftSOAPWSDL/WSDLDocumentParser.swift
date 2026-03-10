import Foundation
import Logging

/// Parses WSDL 1.1 documents into a ``WSDLDefinition`` model.
///
/// `WSDLDocumentParser` reads raw WSDL XML bytes and produces a structured
/// ``WSDLDefinition`` that can be passed to ``CodeGenerationIRBuilder`` to generate
/// Swift client code, or inspected directly for service metadata.
///
/// The parser handles WSDL 1.1 documents including:
/// - Inline and referenced XSD type definitions
/// - Multiple services, port types, bindings, and operations
/// - SOAP 1.1 and SOAP 1.2 binding extensions
///
/// ## Example
/// ```swift
/// let parser = WSDLDocumentParser()
/// let definition = try parser.parse(data: wsdlData)
/// print(definition.services.map(\.name))
/// ```
///
/// - SeeAlso: ``WSDLDefinition``, ``WSDLParsingError``
public struct WSDLDocumentParser: Sendable {
    let logger: Logger

    /// Creates a WSDL document parser.
    ///
    /// - Parameter logger: An optional `swift-log` logger. Defaults to a module-scoped logger.
    public init(logger: Logger? = nil) {
        self.logger = logger ?? Self.defaultLogger()
    }

    #if swift(>=6.0)
    /// Parses a WSDL 1.1 document from raw XML data.
    ///
    /// - Parameter data: The raw WSDL document bytes (typically UTF-8 XML).
    /// - Returns: A ``WSDLDefinition`` representing the parsed service description.
    /// - Throws: ``WSDLParsingError`` on any structural or content violation.
    public func parse(data: Data) throws(WSDLParsingError) -> WSDLDefinition {
        do {
            return try parseDocument(data: data, sourceURL: nil)
        } catch let error as WSDLParsingError {
            throw error
        } catch {
            throw WSDLParsingError.other(underlyingError: error, message: "Unexpected WSDL parsing failure.")
        }
    }
    #else
    /// Parses a WSDL 1.1 document from raw XML data.
    ///
    /// - Parameter data: The raw WSDL document bytes (typically UTF-8 XML).
    /// - Returns: A ``WSDLDefinition`` representing the parsed service description.
    /// - Throws: ``WSDLParsingError`` on any structural or content violation.
    public func parse(data: Data) throws -> WSDLDefinition {
        try parseDocument(data: data, sourceURL: nil)
    }
    #endif

    #if swift(>=6.0)
    /// Parses a WSDL 1.1 document from raw XML data, associating it with a source URL.
    ///
    /// Pass `sourceURL` to enable resolution of relative `<import>` locations within the document.
    ///
    /// - Parameters:
    ///   - data: The raw WSDL document bytes.
    ///   - sourceURL: The base URL of the document, used for resolving relative imports.
    /// - Returns: A ``WSDLDefinition`` representing the parsed service description.
    /// - Throws: ``WSDLParsingError`` on any structural or content violation.
    public func parse(data: Data, sourceURL: URL) throws(WSDLParsingError) -> WSDLDefinition {
        do {
            return try parseDocument(data: data, sourceURL: sourceURL)
        } catch let error as WSDLParsingError {
            throw error
        } catch {
            throw WSDLParsingError.other(underlyingError: error, message: "Unexpected WSDL parsing failure.")
        }
    }
    #else
    /// Parses a WSDL 1.1 document from raw XML data, associating it with a source URL.
    ///
    /// - Parameters:
    ///   - data: The raw WSDL document bytes.
    ///   - sourceURL: The base URL of the document, used for resolving relative imports.
    /// - Returns: A ``WSDLDefinition`` representing the parsed service description.
    /// - Throws: ``WSDLParsingError`` on any structural or content violation.
    public func parse(data: Data, sourceURL: URL) throws -> WSDLDefinition {
        try parseDocument(data: data, sourceURL: sourceURL)
    }
    #endif

    private static func defaultLogger() -> Logger {
        Logger(label: "org.swift.soap.SwiftSOAPWSDL")
    }
}
