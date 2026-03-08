public struct SOAPAttachmentManifest: Sendable, Codable, Equatable {
    public static let empty = SOAPAttachmentManifest(attachments: [])

    public let attachments: [SOAPAttachment]

    public init(attachments: [SOAPAttachment]) {
        self.attachments = attachments
    }
}
