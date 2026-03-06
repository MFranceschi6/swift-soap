import Foundation

public protocol SOAPClientTransport: Sendable {
    #if swift(>=6.0)
    func send(_ requestXMLData: Data, to endpointURL: URL, soapAction: String?) async throws(any Error) -> Data
    #else
    func send(_ requestXMLData: Data, to endpointURL: URL, soapAction: String?) async throws -> Data
    #endif
}
