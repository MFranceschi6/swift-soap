import Foundation

public enum SOAPFaultCode: Sendable, Equatable {
    case versionMismatch
    case mustUnderstand
    case client
    case server
    case sender
    case receiver
    case dataEncodingUnknown
    case custom(String)

    public init(rawValue: String) throws {
        let cleanedRawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedRawValue.isEmpty else {
            throw SOAPCoreError.invalidFault(message: "Fault code cannot be empty.")
        }

        let lookupToken = SOAPFaultCode.lookupToken(from: cleanedRawValue)
        switch lookupToken {
        case "versionmismatch":
            self = .versionMismatch
        case "mustunderstand":
            self = .mustUnderstand
        case "client":
            self = .client
        case "server":
            self = .server
        case "sender":
            self = .sender
        case "receiver":
            self = .receiver
        case "dataencodingunknown":
            self = .dataEncodingUnknown
        default:
            self = .custom(cleanedRawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .versionMismatch:
            return "VersionMismatch"
        case .mustUnderstand:
            return "MustUnderstand"
        case .client:
            return "Client"
        case .server:
            return "Server"
        case .sender:
            return "Sender"
        case .receiver:
            return "Receiver"
        case .dataEncodingUnknown:
            return "DataEncodingUnknown"
        case .custom(let rawValue):
            return rawValue
        }
    }

    private static func lookupToken(from rawValue: String) -> String {
        let maybeQNameSuffix = rawValue.split(separator: ":").last.map(String.init) ?? rawValue
        return maybeQNameSuffix.lowercased()
    }
}
