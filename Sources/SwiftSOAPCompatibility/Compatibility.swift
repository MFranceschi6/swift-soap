#if swift(>=5.6)
@preconcurrency @_exported import CLibXML2
#else
@_exported import CLibXML2
#endif

#if swift(>=6.0)
public typealias SOAPAnyError = any Error
#else
public typealias SOAPAnyError = Error
#endif
