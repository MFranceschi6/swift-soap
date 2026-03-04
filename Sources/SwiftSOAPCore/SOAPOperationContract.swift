public protocol SOAPOperationContract: Sendable {
    associatedtype RequestPayload: SOAPBodyPayload
    associatedtype ResponsePayload: SOAPBodyPayload
    associatedtype FaultDetailPayload: SOAPFaultDetailPayload

    static var operationIdentifier: SOAPOperationIdentifier { get }
    static var soapAction: SOAPAction? { get }
}
