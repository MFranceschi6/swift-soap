import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftSOAPXMLMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        XMLAttributeMacro.self,
        XMLElementMacro.self,
        XMLCodableMacro.self,
    ]
}
