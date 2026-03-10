/// An ordered collection of ``SOAPAttachment`` items declared alongside a SOAP envelope
/// in a multipart transport message.
///
/// The codec uses the manifest to resolve `cid:` references embedded in the XML during
/// decoding. An attachment must be present in the manifest for every `cid:` reference
/// that appears in the envelope; missing references cause
/// ``SOAPCoreError/missingAttachmentReference(contentID:message:)``.
///
/// Use ``SOAPAttachmentManifest/empty`` when no attachments are present.
///
/// - SeeAlso: ``SOAPAttachment``, ``SOAPTransportMessage``
public struct SOAPAttachmentManifest: Sendable, Codable, Equatable {
    /// A manifest with no attachments. Use for operations that carry no binary parts.
    public static let empty = SOAPAttachmentManifest(attachments: [])

    /// The ordered list of attachments.
    public let attachments: [SOAPAttachment]

    /// Creates a manifest from an array of attachments.
    ///
    /// - Parameter attachments: The binary parts to include in the manifest.
    public init(attachments: [SOAPAttachment]) {
        self.attachments = attachments
    }
}
