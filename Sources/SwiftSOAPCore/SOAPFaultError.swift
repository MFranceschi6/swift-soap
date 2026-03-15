/// A typed, throwable wrapper around a decoded SOAP fault.
///
/// `SOAPFaultError` is the canonical `Error` thrown by the ergonomic `invoke` and
/// `invokeOneWay` methods on the client runtime, and by handlers registered via the
/// ergonomic `register` and `registerOneWay` paths on the server.
///
/// On the client side, when the low-level invocation returns
/// ``SOAPOperationResponse/fault(_:)``, the ergonomic wrapper converts the fault
/// into a `SOAPFaultError` and throws it, so callers can use normal `do/catch`:
///
/// ```swift
/// do {
///     let response = try await client.invoke(GetWeather.self, request: req, endpointURL: url)
///     print(response.temperature)
/// } catch let fault as SOAPFaultError<GetWeather.FaultDetailPayload> {
///     print("SOAP fault:", fault.fault.faultString)
/// } catch {
///     print("Transport error:", error)
/// }
/// ```
///
/// On the server side, an ergonomic handler may throw `SOAPFaultError` to return a
/// declared SOAP fault; the registrar adapter converts it back into a raw
/// ``SOAPOperationResponse/fault(_:)`` before forwarding to the transport.
///
/// - SeeAlso: ``SOAPFault``, ``SOAPFaultDetailPayload``
public struct SOAPFaultError<Detail: SOAPFaultDetailPayload>: Error, Sendable {
    /// The underlying SOAP fault that caused this error.
    public let fault: SOAPFault<Detail>

    /// Creates a `SOAPFaultError` wrapping the given SOAP fault.
    ///
    /// - Parameter fault: The decoded SOAP fault.
    public init(fault: SOAPFault<Detail>) {
        self.fault = fault
    }
}

extension SOAPFaultError: Equatable where Detail: Equatable {}
