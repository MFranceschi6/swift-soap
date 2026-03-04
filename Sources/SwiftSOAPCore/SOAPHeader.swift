public struct SOAPHeader<Payload: SOAPHeaderPayload>: Sendable, Codable {
    public let payload: Payload

    public init(payload: Payload) {
        self.payload = payload
    }
}

extension SOAPHeader: Equatable where Payload: Equatable {}
