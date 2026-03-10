import Foundation

/// A single binary attachment carried alongside a SOAP envelope in a multipart message
/// (MTOM/XOP or SwA — SOAP with Attachments).
///
/// Each attachment is identified by a `contentID` that matches a `cid:` reference
/// in the XML envelope. The codec resolves these references during decoding via
/// ``SOAPAttachmentManifest``.
///
/// - SeeAlso: ``SOAPAttachmentManifest``, ``SOAPTransportMessage``
public struct SOAPAttachment: Sendable, Codable, Equatable {
    /// The MIME content identifier for this attachment (without the `cid:` scheme prefix).
    ///
    /// This value corresponds to the `href` or `Include` reference in the XML envelope.
    public let contentID: String
    /// The MIME `Content-Type` of the attachment payload, if known (e.g. `"image/png"`).
    public let contentType: String?
    /// The raw binary payload of the attachment.
    public let payload: Data

    /// Creates a SOAP attachment.
    ///
    /// - Parameters:
    ///   - contentID: The MIME content ID matching the `cid:` reference in the envelope.
    ///   - contentType: The optional MIME content type of the payload.
    ///   - payload: The raw binary attachment data.
    public init(contentID: String, contentType: String? = nil, payload: Data) {
        self.contentID = contentID
        self.contentType = contentType
        self.payload = payload
    }
}
