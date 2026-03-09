#if swift(<5.7)
public protocol SOAPBindingOperationContract: SOAPOperationContract, _SOAPHasBindingMetadata {
    static var bindingMetadata: SOAPBindingMetadata { get }
}
#else
public protocol SOAPBindingOperationContract: SOAPOperationContract {
    static var bindingMetadata: SOAPBindingMetadata { get }
}
#endif
