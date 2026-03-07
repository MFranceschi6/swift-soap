import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftSOAPXMLMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        XMLNodeMappingMacro.self
    ]
}
