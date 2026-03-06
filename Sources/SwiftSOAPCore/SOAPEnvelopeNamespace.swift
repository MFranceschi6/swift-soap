import Foundation

public enum SOAPEnvelopeNamespace: Sendable, Equatable {
    case soap11
    case soap12
    case custom(String)

    #if swift(>=6.0)
    public init(uri: String) throws(SOAPCoreError) {
        let cleanedURI = uri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedURI.isEmpty else {
            throw SOAPCoreError.invalidEnvelope(message: "Envelope namespace URI cannot be empty.")
        }

        switch cleanedURI {
        case SOAPEnvelopeNamespace.soap11.uri:
            self = .soap11
        case SOAPEnvelopeNamespace.soap12.uri:
            self = .soap12
        default:
            self = .custom(cleanedURI)
        }
    }
    #else
    public init(uri: String) throws {
        let cleanedURI = uri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedURI.isEmpty else {
            throw SOAPCoreError.invalidEnvelope(message: "Envelope namespace URI cannot be empty.")
        }

        switch cleanedURI {
        case SOAPEnvelopeNamespace.soap11.uri:
            self = .soap11
        case SOAPEnvelopeNamespace.soap12.uri:
            self = .soap12
        default:
            self = .custom(cleanedURI)
        }
    }
    #endif

    public var uri: String {
        switch self {
        case .soap11:
            return "http://schemas.xmlsoap.org/soap/envelope/"
        case .soap12:
            return "http://www.w3.org/2003/05/soap-envelope"
        case .custom(let uri):
            return uri
        }
    }
}
