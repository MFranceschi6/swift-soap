import Foundation

public typealias SOAPRequestHandler = @Sendable (Data) async throws -> Data

public protocol SOAPServerTransport: Sendable {
    func start(handler: @escaping SOAPRequestHandler) async throws
    func stop() async throws
}
