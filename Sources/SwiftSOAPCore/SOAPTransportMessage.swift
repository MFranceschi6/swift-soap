import Foundation

/// A complete SOAP transport-level message: the serialised XML envelope plus
/// any binary attachments declared in the attachment manifest.
///
/// `SOAPTransportMessage` is the unit exchanged by ``SOAPClientAttachmentTransport``
/// when the operation carries MTOM/XOP or SwA (SOAP with Attachments) binary parts.
///
/// When no attachments are present, use the ``init(envelopeXMLData:)`` convenience
/// initialiser (the manifest defaults to ``SOAPAttachmentManifest/empty``).
///
/// - SeeAlso: ``SOAPClientAttachmentTransport``, ``SOAPAttachmentManifest``
public struct SOAPTransportMessage: Sendable, Codable, Equatable {
    /// The serialised SOAP envelope as UTF-8 XML bytes.
    public let envelopeXMLData: Data
    /// The manifest of binary attachments accompanying the envelope.
    public let attachmentManifest: SOAPAttachmentManifest

    /// Creates a transport message with the given envelope and attachment manifest.
    ///
    /// - Parameters:
    ///   - envelopeXMLData: The serialised SOAP envelope bytes.
    ///   - attachmentManifest: The attachment manifest. Defaults to ``SOAPAttachmentManifest/empty``.
    public init(
        envelopeXMLData: Data,
        attachmentManifest: SOAPAttachmentManifest = .empty
    ) {
        self.envelopeXMLData = envelopeXMLData
        self.attachmentManifest = attachmentManifest
    }
}
