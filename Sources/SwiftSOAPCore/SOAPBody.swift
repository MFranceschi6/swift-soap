public enum SOAPBodyContent<Payload: SOAPBodyPayload, FaultDetail: SOAPFaultDetailPayload>: Sendable, Codable {
    case payload(Payload)
    case fault(SOAPFault<FaultDetail>)
}

extension SOAPBodyContent: Equatable where Payload: Equatable, FaultDetail: Equatable {}

public struct SOAPBody<Payload: SOAPBodyPayload, FaultDetail: SOAPFaultDetailPayload>: Sendable, Codable {
    public let content: SOAPBodyContent<Payload, FaultDetail>
}

extension SOAPBody: Equatable where Payload: Equatable, FaultDetail: Equatable {}
