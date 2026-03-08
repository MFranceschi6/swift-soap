import Foundation

public struct SOAPTransportMessage: Sendable, Codable, Equatable {
    public let envelopeXMLData: Data
    public let attachmentManifest: SOAPAttachmentManifest

    public init(
        envelopeXMLData: Data,
        attachmentManifest: SOAPAttachmentManifest = .empty
    ) {
        self.envelopeXMLData = envelopeXMLData
        self.attachmentManifest = attachmentManifest
    }
}
