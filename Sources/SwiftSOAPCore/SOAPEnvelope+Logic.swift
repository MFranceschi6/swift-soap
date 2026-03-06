public extension SOAPEnvelope where HeaderPayload == SOAPEmptyHeaderPayload {
    init(
        payload: BodyPayload,
        namespace: SOAPEnvelopeNamespace = .soap11
    ) {
        self.init(payload: payload, namespace: namespace, header: nil)
    }

    #if swift(>=6.0)
    init(
        payload: BodyPayload,
        namespaceURI: String
    ) throws(SOAPCoreError) {
        try self.init(
            payload: payload,
            namespace: SOAPEnvelopeNamespace(uri: namespaceURI),
            header: nil
        )
    }
    #else
    init(
        payload: BodyPayload,
        namespaceURI: String
    ) throws {
        try self.init(
            payload: payload,
            namespace: SOAPEnvelopeNamespace(uri: namespaceURI),
            header: nil
        )
    }
    #endif

    init(
        fault: SOAPFault<FaultDetailPayload>,
        namespace: SOAPEnvelopeNamespace = .soap11
    ) {
        self.init(fault: fault, namespace: namespace, header: nil)
    }

    #if swift(>=6.0)
    init(
        fault: SOAPFault<FaultDetailPayload>,
        namespaceURI: String
    ) throws(SOAPCoreError) {
        try self.init(
            fault: fault,
            namespace: SOAPEnvelopeNamespace(uri: namespaceURI),
            header: nil
        )
    }
    #else
    init(
        fault: SOAPFault<FaultDetailPayload>,
        namespaceURI: String
    ) throws {
        try self.init(
            fault: fault,
            namespace: SOAPEnvelopeNamespace(uri: namespaceURI),
            header: nil
        )
    }
    #endif
}
