/// An extension of ``SOAPOperationContract`` for operations that explicitly declare
/// their WSDL binding metadata.
///
/// Conform to `SOAPBindingOperationContract` when the service uses a binding other
/// than the default (document/literal, SOAP 1.1), or when the codec must validate
/// the binding combination at runtime.
///
/// The ``SOAPXMLWireCodec`` detects this conformance and runs
/// ``SOAPBindingCodecFactory/makeCodecStrategy(for:)`` to validate the declared
/// binding before encoding or decoding.
///
/// ## Example
/// ```swift
/// struct GetWeatherOperation: SOAPBindingOperationContract {
///     // ... payload types and operationIdentifier ...
///
///     static let bindingMetadata = SOAPBindingMetadata(
///         envelopeVersion: .soap11,
///         style: .document,
///         bodyUse: .literal
///     )
/// }
/// ```
///
/// - SeeAlso: ``SOAPOperationContract``, ``SOAPBindingMetadata``, ``SOAPBindingCodecStrategy``
#if swift(<5.7)
public protocol SOAPBindingOperationContract: SOAPOperationContract, _SOAPHasBindingMetadata {
    /// The WSDL binding metadata that describes how the message body is serialised.
    static var bindingMetadata: SOAPBindingMetadata { get }
}
#else
public protocol SOAPBindingOperationContract: SOAPOperationContract {
    /// The WSDL binding metadata that describes how the message body is serialised.
    static var bindingMetadata: SOAPBindingMetadata { get }
}
#endif
