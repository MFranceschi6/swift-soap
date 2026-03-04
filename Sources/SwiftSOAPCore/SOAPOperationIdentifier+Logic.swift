import Foundation

extension SOAPOperationIdentifier {
    public init(rawValue: String) {
        normalizedRawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
