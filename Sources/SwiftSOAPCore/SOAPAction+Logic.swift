import Foundation

extension SOAPAction {
    public init(rawValue: String) {
        normalizedRawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
