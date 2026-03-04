public struct SOAPAction: Sendable, Hashable, Codable {
    let normalizedRawValue: String

    public var rawValue: String {
        normalizedRawValue
    }
}
