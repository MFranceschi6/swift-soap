public protocol SOAPHeaderPayload: Codable, Sendable {}

public struct SOAPEmptyHeaderPayload: SOAPHeaderPayload, Equatable {
    public init() {}
}
