import Foundation

/// A closure type representing the server-side handler for a raw SOAP request.
///
/// The handler receives the raw request XML bytes and must return raw response XML bytes.
/// The ``SOAPServerTransport`` implementation owns HTTP-level concerns (parsing headers,
/// writing status codes); the handler owns SOAP-level concerns (decoding the envelope,
/// dispatching to an operation implementation, encoding the response).
#if swift(>=6.0)
public typealias SOAPRequestHandler = @Sendable (Data) async throws(any Error) -> Data
#else
public typealias SOAPRequestHandler = @Sendable (Data) async throws -> Data
#endif

/// The server-side transport abstraction that listens for incoming SOAP requests and
/// dispatches them to a ``SOAPRequestHandler``.
///
/// The library provides no concrete server implementation — this is intentional. Your
/// application framework (Vapor, Hummingbird, NIO, etc.) provides the HTTP listener;
/// you write an implementation that bridges framework-level routing to this protocol.
///
/// ## Implementing a server transport
/// ```swift
/// struct VaporSOAPServerTransport: SOAPServerTransport {
///     let app: Application
///     let path: String
///
///     func start(handler: @escaping SOAPRequestHandler) async throws {
///         app.post(path) { req async throws -> Response in
///             let responseData = try await handler(req.body.data ?? Data())
///             return Response(body: .init(data: responseData))
///         }
///     }
///
///     func stop() async throws {
///         // Deregister the route or shut down the listener
///     }
/// }
/// ```
public protocol SOAPServerTransport: Sendable {
    #if swift(>=6.0)
    /// Starts listening for incoming SOAP requests and dispatches them to `handler`.
    ///
    /// - Parameter handler: The closure that receives request XML bytes and returns response XML bytes.
    /// - Throws: Any error from the underlying transport setup.
    func start(handler: @escaping SOAPRequestHandler) async throws(any Error)
    /// Stops listening for incoming SOAP requests.
    ///
    /// - Throws: Any error from the underlying transport teardown.
    func stop() async throws(any Error)
    #else
    /// Starts listening for incoming SOAP requests and dispatches them to `handler`.
    ///
    /// - Parameter handler: The closure that receives request XML bytes and returns response XML bytes.
    /// - Throws: Any error from the underlying transport setup.
    func start(handler: @escaping SOAPRequestHandler) async throws
    /// Stops listening for incoming SOAP requests.
    ///
    /// - Throws: Any error from the underlying transport teardown.
    func stop() async throws
    #endif
}
