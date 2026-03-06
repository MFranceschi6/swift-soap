import Foundation

#if swift(>=6.0)
public typealias SOAPRequestHandler = @Sendable (Data) async throws(any Error) -> Data
#else
public typealias SOAPRequestHandler = @Sendable (Data) async throws -> Data
#endif

public protocol SOAPServerTransport: Sendable {
    #if swift(>=6.0)
    func start(handler: @escaping SOAPRequestHandler) async throws(any Error)
    func stop() async throws(any Error)
    #else
    func start(handler: @escaping SOAPRequestHandler) async throws
    func stop() async throws
    #endif
}
