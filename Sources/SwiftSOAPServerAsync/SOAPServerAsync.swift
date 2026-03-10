import SwiftSOAPCore

/// A typed async closure that handles a single SOAP operation on the server side.
///
/// Receives the decoded request payload and must return a ``SOAPOperationResponse``.
/// Register handlers via ``SOAPServerAsync/register(_:handler:)``.
#if swift(>=6.0)
public typealias SOAPAsyncOperationHandler<Operation: SOAPOperationContract> = @Sendable (
    Operation.RequestPayload
) async throws(any Error) -> SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>
#else
public typealias SOAPAsyncOperationHandler<Operation: SOAPOperationContract> = @Sendable (
    Operation.RequestPayload
) async throws -> SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>
#endif

/// An async SOAP server that dispatches incoming operations to registered handlers.
///
/// Implement `SOAPServerAsync` to build a SOAP server on top of any async framework
/// (Vapor, Hummingbird, etc.). The library does not provide a concrete implementation;
/// this protocol defines the dispatch contract between the framework adapter and the
/// application-level operation handlers.
///
/// ## Typical usage
/// ```swift
/// let server: any SOAPServerAsync = MyVaporSOAPServer(app: app, path: "/service")
/// try await server.register(GetWeatherOperation.self) { request in
///     let temperature = try await weatherService.lookup(city: request.cityName)
///     return .success(.init(temperature: temperature))
/// }
/// try await server.start()
/// ```
///
/// - SeeAlso: ``SOAPServerTransport``, ``SOAPOperationContract``, ``SOAPAsyncOperationHandler``
public protocol SOAPServerAsync: Sendable {
    #if swift(>=6.0)
    /// Registers a typed handler for the given operation.
    ///
    /// - Parameters:
    ///   - operation: The operation type to handle.
    ///   - handler: A `Sendable` async closure that receives the request payload and returns a response.
    /// - Throws: Any error from the underlying registration mechanism.
    func register<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        handler: @escaping SOAPAsyncOperationHandler<Operation>
    ) async throws(any Error)

    /// Starts the server and begins accepting requests.
    ///
    /// - Throws: Any error from the underlying transport start.
    func start() async throws(any Error)

    /// Stops the server and ceases accepting requests.
    ///
    /// - Throws: Any error from the underlying transport stop.
    func stop() async throws(any Error)
    #else
    /// Registers a typed handler for the given operation.
    ///
    /// - Parameters:
    ///   - operation: The operation type to handle.
    ///   - handler: A `Sendable` async closure that receives the request payload and returns a response.
    /// - Throws: Any error from the underlying registration mechanism.
    func register<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        handler: @escaping SOAPAsyncOperationHandler<Operation>
    ) async throws

    /// Starts the server and begins accepting requests.
    ///
    /// - Throws: Any error from the underlying transport start.
    func start() async throws

    /// Stops the server and ceases accepting requests.
    ///
    /// - Throws: Any error from the underlying transport stop.
    func stop() async throws
    #endif
}
