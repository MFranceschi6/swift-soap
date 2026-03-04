public protocol SOAPFaultDetailPayload: Codable, Sendable {}

public struct SOAPEmptyFaultDetailPayload: SOAPFaultDetailPayload, Equatable {
    public init() {}
}
