//
//  JSONConvertibleMacro.swift
//  JSONMacros
//
//  Created by Reid Chatham on 4/5/25.
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - JSONConvertibleMacro

/// Implements the `@JSONSchema` attached extension macro.
///
/// Inspects each stored `let`/`var` property of a struct declaration and
/// generates a `JSONConvertible` extension with a `jsonSchema` static property.
///
/// Improvements:
/// - Emits a proper compile-time diagnostic if applied to a non-struct/non-enum type.
/// - Respects a custom `CodingKeys` enum.
/// - Recognises `enum Foo: String, Codable` nested types → `.string(enumValues: [...])`
/// - Auto-generates `title` from struct name (#14)
/// - Extracts `description` from doc comments on struct and properties (#15)
/// - Supports `Set<T>` → `.array(items:, uniqueItems: true)` (#16)
/// - Properties with default values are excluded from `required` (#17)
/// - `@JSONSchema` on top-level String raw-value enums → `enumValues` (#27)
/// - `@JSONSchema` on top-level associated-value enums → `oneOf` schemas (#27)
public struct JSONConvertibleMacro: ExtensionMacro {

    // MARK: - ExtensionMacro conformance

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {

        let typeName = type.trimmedDescription

        // #27 — Handle enum declarations separately
        if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            return try expandEnum(enumDecl, typeName: typeName, node: node, context: context)
        }

        // Guard: only structs are supported (besides enums handled above).
        guard declaration.is(StructDeclSyntax.self) else {
            let diagnostic = MacroExpansionErrorMessage(
                "@JSONSchema can only be applied to a struct or enum"
            )
            context.diagnose(Diagnostic(node: node, message: diagnostic))
            return []
        }

        let members = declaration.memberBlock.members

        // #14 — Auto-generate title from struct name.
        let autoTitle = typeName

        // #15 — Extract description from doc comment on the struct/class.
        let structDescription = extractDocComment(from: declaration.as(StructDeclSyntax.self)?.leadingTrivia)

        // Build CodingKeys map: Swift property name → encoded key string.
        let codingKeysMap = extractCodingKeys(from: members)

        // Collect nested String-raw-value enums so we can emit enumValues.
        let stringEnums = extractStringEnums(from: members)

        // Collect stored properties.
        var propertyEntries: [(encodedName: String, schemaExpr: String, isOptional: Bool)] = []

        for member in members {
            guard
                let varDecl = member.decl.as(VariableDeclSyntax.self),
                varDecl.bindingSpecifier.tokenKind == .keyword(.let) ||
                varDecl.bindingSpecifier.tokenKind == .keyword(.var)
            else { continue }

            // #15 — Extract description from property doc comment.
            let propDescription = extractDocComment(from: varDecl.leadingTrivia)

            for binding in varDecl.bindings {
                // Skip computed properties (have an accessor block).
                if binding.accessorBlock != nil { continue }

                guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
                let swiftName = pattern.identifier.text

                guard let typeAnnotation = binding.typeAnnotation else { continue }
                let typeSyntax = typeAnnotation.type

                // #17 — Properties with a default value (initializer) are optional in required[].
                let hasDefaultValue = binding.initializer != nil
                let isOptionalByDefault = hasDefaultValue

                let encodedName = codingKeysMap[swiftName] ?? swiftName
                var (schemaExpr, isOptional) = schemaExpression(
                    for: typeSyntax,
                    stringEnums: stringEnums,
                    description: propDescription
                )

                // Inject description into schema expression if present
                // (schemaExpression already handles this via the description param)

                if isOptionalByDefault { isOptional = true }
                propertyEntries.append((encodedName: encodedName, schemaExpr: schemaExpr, isOptional: isOptional))
            }
        }

        // Build the properties dictionary entries.
        let propsLines = propertyEntries
            .map { "        \"\($0.encodedName)\": \($0.schemaExpr)," }
            .joined(separator: "\n")

        let requiredNames = propertyEntries
            .filter { !$0.isOptional }
            .map { "\"\($0.encodedName)\"" }
        let requiredValue = requiredNames.isEmpty
            ? "nil"
            : "[\(requiredNames.joined(separator: ", "))]"

        // #14 — Include title; #15 — include description if present.
        let descLine: String
        if let desc = structDescription {
            let escapedDesc = desc.replacingOccurrences(of: "\"", with: "\\\"")
            descLine = "\n            description: \"\(escapedDesc)\","
        } else {
            descLine = ""
        }

        let extensionSource = """
        extension \(typeName): JSONConvertible, JSONSchemaProviding {
            public static var jsonSchema: JSONSchema {
                .object(
                    properties: [
        \(propsLines)
                    ],
                    required: \(requiredValue),
                    additionalProperties: .bool(false),\(descLine)
                    title: "\(autoTitle)"
                )
            }
        }
        """

        let extensionDecl = try ExtensionDeclSyntax(SyntaxNodeString(stringLiteral: extensionSource))
        return [extensionDecl]
    }

    // MARK: - #27 Enum expansion

    private static func expandEnum(
        _ enumDecl: EnumDeclSyntax,
        typeName: String,
        node: AttributeSyntax,
        context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {

        // Check if it's a String raw-value enum.
        let isStringEnum = enumDecl.inheritanceClause?.inheritedTypes.contains {
            $0.type.trimmedDescription == "String"
        } ?? false

        if isStringEnum {
            // String raw-value enum → .string(enumValues: [...])
            var cases: [String] = []
            for member in enumDecl.memberBlock.members {
                guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else { continue }
                for element in caseDecl.elements {
                    if let rawValue = element.rawValue?.value.as(StringLiteralExprSyntax.self) {
                        cases.append(rawValue.representedLiteralValue ?? element.name.text)
                    } else {
                        cases.append(element.name.text)
                    }
                }
            }
            let quoted = cases.map { "\"\($0)\"" }.joined(separator: ", ")
            let extensionSource = """
            extension \(typeName): JSONSchemaProviding {
                public static var jsonSchema: JSONSchema {
                    .string(enumValues: [\(quoted)])
                }
            }
            """
            let extensionDecl = try ExtensionDeclSyntax(SyntaxNodeString(stringLiteral: extensionSource))
            return [extensionDecl]
        }

        // Associated-value enum → oneOf schemas
        // Each case becomes a oneOf option.
        var caseSchemas: [String] = []
        for member in enumDecl.memberBlock.members {
            guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else { continue }
            for element in caseDecl.elements {
                let caseName = element.name.text
                if let paramClause = element.parameterClause, !paramClause.parameters.isEmpty {
                    // Has associated values → object schema with one property per value
                    let params = paramClause.parameters
                    if params.count == 1, let param = params.first {
                        let innerType = param.type.trimmedDescription
                        let innerSchema = schemaForNamedType(innerType)
                        // Wrap as object {caseName: innerSchema}
                        caseSchemas.append(".object(properties: [\"\(caseName)\": \(innerSchema)], required: [\"\(caseName)\"], additionalProperties: .bool(false))")
                    } else {
                        // Multiple associated values → object with named properties
                        var propLines: [String] = []
                        var reqNames: [String] = []
                        for (i, param) in params.enumerated() {
                            let label = param.firstName?.text ?? "_\(i)"
                            let innerType = param.type.trimmedDescription
                            let innerSchema = schemaForNamedType(innerType)
                            propLines.append("\"\(label)\": \(innerSchema)")
                            reqNames.append("\"\(label)\"")
                        }
                        let propsStr = propLines.joined(separator: ", ")
                        let reqStr = reqNames.joined(separator: ", ")
                        caseSchemas.append(".object(properties: [\(propsStr)], required: [\(reqStr)], additionalProperties: .bool(false))")
                    }
                } else {
                    // No associated values → string constant matching case name
                    caseSchemas.append(".string(enumValues: [\"\(caseName)\"])")
                }
            }
        }

        let schemasStr = caseSchemas.joined(separator: ",\n            ")
        let extensionSource = """
        extension \(typeName): JSONSchemaProviding {
            public static var jsonSchema: JSONSchema {
                .oneOf([
                    \(schemasStr)
                ])
            }
        }
        """
        let extensionDecl = try ExtensionDeclSyntax(SyntaxNodeString(stringLiteral: extensionSource))
        return [extensionDecl]
    }

    // MARK: - CodingKeys extraction

    private static func extractCodingKeys(
        from members: MemberBlockItemListSyntax
    ) -> [String: String] {
        var map: [String: String] = [:]
        for member in members {
            guard let enumDecl = member.decl.as(EnumDeclSyntax.self),
                  enumDecl.name.text == "CodingKeys" else { continue }
            for enumMember in enumDecl.memberBlock.members {
                guard let caseDecl = enumMember.decl.as(EnumCaseDeclSyntax.self) else { continue }
                for element in caseDecl.elements {
                    let swiftName = element.name.text
                    if let rawValue = element.rawValue?.value.as(StringLiteralExprSyntax.self) {
                        let encodedName = rawValue.representedLiteralValue ?? swiftName
                        map[swiftName] = encodedName
                    } else {
                        map[swiftName] = swiftName
                    }
                }
            }
        }
        return map
    }

    // MARK: - String enum extraction (nested enums)

    private static func extractStringEnums(
        from members: MemberBlockItemListSyntax
    ) -> [String: [String]] {
        var result: [String: [String]] = [:]
        for member in members {
            guard let enumDecl = member.decl.as(EnumDeclSyntax.self) else { continue }
            let inheritsFromString = enumDecl.inheritanceClause?.inheritedTypes.contains {
                $0.type.trimmedDescription == "String"
            } ?? false
            guard inheritsFromString else { continue }
            var cases: [String] = []
            for enumMember in enumDecl.memberBlock.members {
                guard let caseDecl = enumMember.decl.as(EnumCaseDeclSyntax.self) else { continue }
                for element in caseDecl.elements {
                    if let rawValue = element.rawValue?.value.as(StringLiteralExprSyntax.self) {
                        cases.append(rawValue.representedLiteralValue ?? element.name.text)
                    } else {
                        cases.append(element.name.text)
                    }
                }
            }
            result[enumDecl.name.text] = cases
        }
        return result
    }

    // MARK: - #15 Doc comment extraction

    private static func extractDocComment(from trivia: Trivia?) -> String? {
        guard let trivia else { return nil }
        var lines: [String] = []
        for piece in trivia {
            switch piece {
            case .docLineComment(let text):
                // Strip leading "/// " or "///"
                let stripped = text.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "^///\\s?", with: "", options: .regularExpression)
                if !stripped.isEmpty { lines.append(stripped) }
            case .docBlockComment(let text):
                // Strip /** ... */ wrapper
                let inner = text
                    .replacingOccurrences(of: "^/\\*\\*", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\\*/$", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !inner.isEmpty { lines.append(inner) }
            default: break
            }
        }
        return lines.isEmpty ? nil : lines.joined(separator: " ")
    }

    // MARK: - Type → JSONSchema expression

    private static func schemaExpression(
        for type: TypeSyntax,
        stringEnums: [String: [String]],
        description: String? = nil
    ) -> (expr: String, isOptional: Bool) {

        // T? (postfix optional)
        if let optionalType = type.as(OptionalTypeSyntax.self) {
            let (inner, _) = schemaExpression(for: optionalType.wrappedType, stringEnums: stringEnums, description: description)
            return (inner, true)
        }

        // Optional<T> (explicit generic)
        if let identType = type.as(IdentifierTypeSyntax.self),
           identType.name.text == "Optional",
           let firstArg = identType.genericArgumentClause?.arguments.first {
            let (inner, _) = schemaExpression(for: firstArg.argument, stringEnums: stringEnums, description: description)
            return (inner, true)
        }

        // Set<T> → array with uniqueItems
        if let identType = type.as(IdentifierTypeSyntax.self),
           identType.name.text == "Set",
           let firstArg = identType.genericArgumentClause?.arguments.first {
            let (itemExpr, _) = schemaExpression(for: firstArg.argument, stringEnums: stringEnums)
            return (".array(items: \(itemExpr), uniqueItems: true)", false)
        }

        // [Element]
        if let arrayType = type.as(ArrayTypeSyntax.self) {
            let (itemExpr, _) = schemaExpression(for: arrayType.element, stringEnums: stringEnums)
            return (".array(items: \(itemExpr)\(formatDescArg(description)))", false)
        }

        // [Key: Value] dictionary
        if let dictType = type.as(DictionaryTypeSyntax.self) {
            let keyName = dictType.key.trimmedDescription
            if keyName == "String" {
                return (".object(properties: [:], additionalProperties: .bool(true))", false)
            }
            return (".object()", false)
        }

        // Named type
        if let identType = type.as(IdentifierTypeSyntax.self) {
            let name = identType.name.text

            // Nested String enum → enumValues
            if let cases = stringEnums[name] {
                let quoted = cases.map { "\"\($0)\"" }.joined(separator: ", ")
                if let desc = description {
                    let escaped = desc.replacingOccurrences(of: "\"", with: "\\\"")
                    return (".string(enumValues: [\(quoted)], description: \"\(escaped)\")", false)
                }
                return (".string(enumValues: [\(quoted)])", false)
            }

            return (schemaForNamedType(name, description: description), false)
        }

        return (".object()", false)
    }

    /// Formats an optional description string as a trailing argument: `, description: "..."`.
    /// Returns an empty string when `description` is `nil`.
    private static func formatDescArg(_ description: String?) -> String {
        guard let desc = description else { return "" }
        let escaped = desc.replacingOccurrences(of: "\"", with: "\\\"")
        return ", description: \"\(escaped)\""
    }

    private static func schemaForNamedType(_ name: String, description: String? = nil) -> String {
        switch name {
        case "String":
            // description is the first (and only) argument for .string()
            if let desc = description {
                let escaped = desc.replacingOccurrences(of: "\"", with: "\\\"")
                return ".string(description: \"\(escaped)\")"
            }
            return ".string()"
        case "Int", "Int8", "Int16", "Int32", "Int64",
             "UInt", "UInt8", "UInt16", "UInt32", "UInt64":    return ".integer()"
        case "Double", "Float", "Float32", "Float64",
             "CGFloat", "Decimal":                              return ".number()"
        case "Bool":                                            return ".boolean()"
        case "Date":                                            return ".string(description: \"ISO 8601 date-time\")"
        case "URL":                                             return ".string(description: \"URL\")"
        case "UUID":                                            return ".string(description: \"UUID\")"
        default:                                                return ".from(\(name).self)"
        }
    }
}

// MARK: - Diagnostic helper

private struct MacroExpansionErrorMessage: DiagnosticMessage {
    let message: String
    let diagnosticID: MessageID
    let severity: DiagnosticSeverity

    init(_ message: String) {
        self.message = message
        self.diagnosticID = MessageID(domain: "JSONMacros", id: message)
        self.severity = .error
    }
}
