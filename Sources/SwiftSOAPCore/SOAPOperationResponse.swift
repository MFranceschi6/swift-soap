// swiftlint:disable:next line_length
public enum SOAPOperationResponse<ResponsePayload: SOAPBodyPayload, FaultDetailPayload: SOAPFaultDetailPayload>: Sendable, Codable {
    case success(ResponsePayload)
    case fault(SOAPFault<FaultDetailPayload>)
}
