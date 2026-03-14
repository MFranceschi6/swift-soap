import Foundation

extension SOAPAction {
    public init(rawValue: String) {
        normalizedRawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public init<E: RawRepresentable>(_ value: E) where E.RawValue == String {
        normalizedRawValue = value.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
