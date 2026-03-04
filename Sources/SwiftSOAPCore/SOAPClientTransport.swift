import Foundation

public protocol SOAPClientTransport: Sendable {
    func send(_ requestXMLData: Data, to endpointURL: URL, soapAction: String?) async throws -> Data
}
