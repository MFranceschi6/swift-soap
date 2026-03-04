public protocol SOAPBodyPayload: Codable, Sendable {}

public struct SOAPEmptyPayload: SOAPBodyPayload, Equatable {
    public init() {}
}
