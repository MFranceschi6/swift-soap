import Foundation
import Logging

public struct WSDLDocumentParser: Sendable {
    let logger: Logger

    public init(logger: Logger? = nil) {
        self.logger = logger ?? Self.defaultLogger()
    }

    #if swift(>=6.0)
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
    public func parse(data: Data) throws -> WSDLDefinition {
        try parseDocument(data: data, sourceURL: nil)
    }
    #endif

    #if swift(>=6.0)
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
    public func parse(data: Data, sourceURL: URL) throws -> WSDLDefinition {
        try parseDocument(data: data, sourceURL: sourceURL)
    }
    #endif

    private static func defaultLogger() -> Logger {
        Logger(label: "org.swift.soap.SwiftSOAPWSDL")
    }
}
