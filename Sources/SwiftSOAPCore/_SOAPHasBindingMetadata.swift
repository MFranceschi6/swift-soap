#if swift(<5.7)
// Swift 5.6 cannot cast to a protocol metatype when the protocol has associated
// types (SE-0309 existential restriction). A separate no-associated-type protocol
// in the SOAPBindingOperationContract inheritance chain lets the codec cast via
// `as? _SOAPHasBindingMetadata.Type` on that lane.
public protocol _SOAPHasBindingMetadata {
    static var bindingMetadata: SOAPBindingMetadata { get }
}
#endif
