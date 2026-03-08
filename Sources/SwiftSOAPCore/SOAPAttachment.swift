import Foundation

public struct SOAPAttachment: Sendable, Codable, Equatable {
    public let contentID: String
    public let contentType: String?
    public let payload: Data

    public init(contentID: String, contentType: String? = nil, payload: Data) {
        self.contentID = contentID
        self.contentType = contentType
        self.payload = payload
    }
}
