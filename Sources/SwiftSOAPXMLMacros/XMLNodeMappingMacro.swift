@_exported import SwiftSOAPXML

@attached(extension, conformances: XMLFieldCodingOverrideProvider, names: named(xmlFieldNodeKinds))
public macro XMLNodeMapping(
    attributes: [String] = [],
    elements: [String] = []
) = #externalMacro(module: "SwiftSOAPXMLMacroImplementation", type: "XMLNodeMappingMacro")
