extension SOAPEnvelopeNamespace: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let uri = try container.decode(String.self)
        self = try SOAPEnvelopeNamespace(uri: uri)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(uri)
    }
}
