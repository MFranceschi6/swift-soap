import Foundation

extension SOAPAttachmentManifest {
    public func attachment(forContentID contentID: String) -> SOAPAttachment? {
        let normalizedTarget = Self.normalizeContentID(contentID)
        return attachments.first {
            Self.normalizeContentID($0.contentID) == normalizedTarget
        }
    }

    public func containsAttachment(forContentID contentID: String) -> Bool {
        attachment(forContentID: contentID) != nil
    }

    public static func normalizeContentID(_ rawValue: String) -> String {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("cid:") {
            value = String(value.dropFirst(4))
        }
        if value.hasPrefix("<"), value.hasSuffix(">"), value.count >= 2 {
            value = String(value.dropFirst().dropLast())
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
