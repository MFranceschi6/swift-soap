import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct XMLNodeMappingMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo _: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) || declaration.is(ClassDeclSyntax.self) else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(declaration),
                    message: MappingDiagnostic(
                        id: "XML6_6M_INVALID_DECL",
                        message: "@XMLNodeMapping can only be attached to a struct or class declaration."
                    )
                )
            )
            return []
        }

        let mapping = parseMappingArguments(from: node, in: context)
        if mapping.hasFatalError {
            return []
        }

        let entries = mapping.entries.map { entry in
            "\"\(escapeStringLiteral(entry.key))\": .\(entry.value.rawValue)"
        }
        let dictionaryLiteral: String
        if entries.isEmpty {
            dictionaryLiteral = "[:]"
        } else {
            dictionaryLiteral = "[\n            \(entries.joined(separator: ",\n            "))\n        ]"
        }

        let extensionDecl = try ExtensionDeclSyntax(
            """
            extension \(type.trimmed): XMLFieldCodingOverrideProvider {
                static var xmlFieldNodeKinds: [String: XMLFieldNodeKind] {
                    \(raw: dictionaryLiteral)
                }
            }
            """
        )

        return [extensionDecl]
    }

    private static func parseMappingArguments(
        from attribute: AttributeSyntax,
        in context: some MacroExpansionContext
    ) -> ParsedMapping {
        guard let argumentList = attribute.arguments?.as(LabeledExprListSyntax.self) else {
            return ParsedMapping()
        }

        var attributes: [String] = []
        var elements: [String] = []
        var hasFatalError = false

        for argument in argumentList {
            let label = argument.label?.text ?? ""
            guard label == "attributes" || label == "elements" else {
                hasFatalError = true
                context.diagnose(
                    Diagnostic(
                        node: Syntax(argument),
                        message: MappingDiagnostic(
                            id: "XML6_6M_INVALID_ARGUMENT_LABEL",
                            message: "@XMLNodeMapping only accepts 'attributes' and 'elements' argument labels."
                        )
                    )
                )
                continue
            }

            guard let arrayExpression = argument.expression.as(ArrayExprSyntax.self) else {
                hasFatalError = true
                context.diagnose(
                    Diagnostic(
                        node: Syntax(argument.expression),
                        message: MappingDiagnostic(
                            id: "XML6_6M_ARGUMENT_NOT_ARRAY",
                            message: "@XMLNodeMapping argument '\(label)' must be an array of string literals."
                        )
                    )
                )
                continue
            }

            let values = parseStringArray(arrayExpression, in: context)
            if values == nil {
                hasFatalError = true
                continue
            }

            if label == "attributes" {
                attributes = values ?? []
            } else {
                elements = values ?? []
            }
        }

        var seen = Set<String>()
        var entries: [(key: String, value: XMLFieldKindLiteral)] = []
        for key in attributes {
            if seen.insert(key).inserted == false {
                hasFatalError = true
                context.diagnose(
                    Diagnostic(
                        node: Syntax(attribute),
                        message: MappingDiagnostic(
                            id: "XML6_6M_DUPLICATE_FIELD",
                            message: "@XMLNodeMapping contains duplicate field '\(key)'."
                        )
                    )
                )
                continue
            }
            entries.append((key: key, value: .attribute))
        }

        for key in elements {
            if seen.insert(key).inserted == false {
                hasFatalError = true
                context.diagnose(
                    Diagnostic(
                        node: Syntax(attribute),
                        message: MappingDiagnostic(
                            id: "XML6_6M_DUPLICATE_FIELD",
                            message: "@XMLNodeMapping contains duplicate field '\(key)'."
                        )
                    )
                )
                continue
            }
            entries.append((key: key, value: .element))
        }

        return ParsedMapping(entries: entries, hasFatalError: hasFatalError)
    }

    private static func parseStringArray(
        _ arrayExpression: ArrayExprSyntax,
        in context: some MacroExpansionContext
    ) -> [String]? {
        var values: [String] = []

        for arrayItem in arrayExpression.elements {
            let rawValue = arrayItem.expression.description
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard rawValue.hasPrefix("\"") && rawValue.hasSuffix("\"") && rawValue.count >= 2 else {
                context.diagnose(
                    Diagnostic(
                        node: Syntax(arrayItem.expression),
                        message: MappingDiagnostic(
                            id: "XML6_6M_NON_STRING_LITERAL",
                            message: "@XMLNodeMapping array values must be plain string literals."
                        )
                    )
                )
                return nil
            }

            let value = String(rawValue.dropFirst().dropLast())
            if value.contains("\\(") {
                context.diagnose(
                    Diagnostic(
                        node: Syntax(arrayItem.expression),
                        message: MappingDiagnostic(
                            id: "XML6_6M_INTERPOLATION_UNSUPPORTED",
                            message: "@XMLNodeMapping does not support string interpolation in field names."
                        )
                    )
                )
                return nil
            }

            values.append(value)
        }

        return values
    }

    private static func escapeStringLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

private struct ParsedMapping {
    let entries: [(key: String, value: XMLFieldKindLiteral)]
    let hasFatalError: Bool

    init(entries: [(key: String, value: XMLFieldKindLiteral)] = [], hasFatalError: Bool = false) {
        self.entries = entries
        self.hasFatalError = hasFatalError
    }
}

private enum XMLFieldKindLiteral: String {
    case element
    case attribute
}

private struct MappingDiagnostic: DiagnosticMessage {
    let id: String
    let message: String

    var severity: DiagnosticSeverity { .error }
    var diagnosticID: MessageID {
        MessageID(domain: "SwiftSOAPXMLMacro", id: id)
    }
}
