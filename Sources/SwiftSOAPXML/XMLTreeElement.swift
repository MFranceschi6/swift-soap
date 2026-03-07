import Foundation

public struct XMLTreeElement: Sendable, Equatable, Codable {
    public let name: XMLQualifiedName
    public let attributes: [XMLTreeAttribute]
    public let namespaceDeclarations: [XMLNamespaceDeclaration]
    public let children: [XMLTreeNode]
    public let metadata: XMLNodeStructuralMetadata

    public init(
        name: XMLQualifiedName,
        attributes: [XMLTreeAttribute] = [],
        namespaceDeclarations: [XMLNamespaceDeclaration] = [],
        children: [XMLTreeNode] = [],
        metadata: XMLNodeStructuralMetadata = XMLNodeStructuralMetadata()
    ) {
        self.name = name
        self.attributes = attributes
        self.namespaceDeclarations = namespaceDeclarations
        self.children = children
        self.metadata = metadata
    }
}
