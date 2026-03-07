import Foundation

public struct XMLTreeDocument: Sendable, Equatable, Codable {
    public let root: XMLTreeElement
    public let metadata: XMLDocumentStructuralMetadata

    public init(
        root: XMLTreeElement,
        metadata: XMLDocumentStructuralMetadata = XMLDocumentStructuralMetadata()
    ) {
        self.root = root
        self.metadata = metadata
    }
}
