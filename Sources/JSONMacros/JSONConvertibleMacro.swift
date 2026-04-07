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
/// Improvements over the original:
/// - Emits a proper compile-time diagnostic if applied to a non-struct type.
/// - Respects a custom `CodingKeys` enum, using the raw string values as JSON
///   property names rather than the Swift property names.
/// - Recognises `enum Foo: String, Codable` nested types and generates
///   `.string(enumValues: [...])` rather than `.from(Foo.self)`.
/// - Indentation is normalised so expanded source aligns properly in Xcode.
public struct JSONConvertibleMacro: ExtensionMacro {

    // MARK: - ExtensionMacro conformance

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {

        // #17 — Guard: only structs are supported.
        guard declaration.is(StructDeclSyntax.self) else {
            let diagnostic = MacroExpansionErrorMessage(
                "@JSONSchema can only be applied to a struct"
            )
            context.diagnose(Diagnostic(node: node, message: diagnostic))
            return []
        }

        let members = declaration.memberBlock.members

        // #18 — Build a CodingKeys map: Swift property name → encoded key string.
        let codingKeysMap = extractCodingKeys(from: members)

        // #19 — Collect nested String-raw-value enums so we can emit enumValues.
        let stringEnums = extractStringEnums(from: members)

        // Collect stored properties.
        var propertyEntries: [(encodedName: String, schemaExpr: String, isOptional: Bool)] = []

        for member in members {
            guard
                let varDecl = member.decl.as(VariableDeclSyntax.self),
                varDecl.bindingSpecifier.tokenKind == .keyword(.let) ||
                varDecl.bindingSpecifier.tokenKind == .keyword(.var)
            else { continue }

            for binding in varDecl.bindings {
                // Skip computed properties (have an accessor block).
                if binding.accessorBlock != nil { continue }

                guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
                let swiftName = pattern.identifier.text

                guard let typeAnnotation = binding.typeAnnotation else { continue }
                let typeSyntax = typeAnnotation.type

                let encodedName = codingKeysMap[swiftName] ?? swiftName
                let (schemaExpr, isOptional) = schemaExpression(for: typeSyntax, stringEnums: stringEnums)
                propertyEntries.append((encodedName: encodedName, schemaExpr: schemaExpr, isOptional: isOptional))
            }
        }

        // Build the properties dictionary entries (4 spaces indent inside properties block).
        let propsLines = propertyEntries
            .map { "        \"\($0.encodedName)\": \($0.schemaExpr)," }
            .joined(separator: "\n")

        let requiredNames = propertyEntries
            .filter { !$0.isOptional }
            .map { "\"\($0.encodedName)\"" }
        let requiredValue = requiredNames.isEmpty
            ? "nil"
            : "[\(requiredNames.joined(separator: ", "))]"

        let typeName = type.trimmedDescription

        let extensionSource = """
        extension \(typeName): JSONConvertible {
            public static var jsonSchema: JSONSchema {
                .object(
                    properties: [
        \(propsLines)
                    ],
                    required: \(requiredValue),
                    additionalProperties: false
                )
            }
        }
        """

        let extensionDecl = try ExtensionDeclSyntax(SyntaxNodeString(stringLiteral: extensionSource))
        return [extensionDecl]
    }

    // MARK: - CodingKeys extraction (#18)

    /// Extracts the `CodingKeys` enum (if present) and returns a map of
    /// Swift property name → encoded JSON key string.
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
                    // Raw value (= "encoded_name") overrides; otherwise use the case name itself.
                    if let rawValue = element.rawValue?.value.as(StringLiteralExprSyntax.self) {
                        // Use representedLiteralValue to properly handle escape sequences.
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

    // MARK: - String enum extraction (#19)

    /// Returns a set of type names that are `enum Foo: String` (String raw-value enums),
    /// along with their case names as the allowed enum values.
    private static func extractStringEnums(
        from members: MemberBlockItemListSyntax
    ) -> [String: [String]] {
        var result: [String: [String]] = [:]

        for member in members {
            guard let enumDecl = member.decl.as(EnumDeclSyntax.self) else { continue }

            // Check that the enum inherits from String (first inherited type == "String").
            let inheritsFromString = enumDecl.inheritanceClause?.inheritedTypes.contains {
                $0.type.trimmedDescription == "String"
            } ?? false
            guard inheritsFromString else { continue }

            var cases: [String] = []
            for enumMember in enumDecl.memberBlock.members {
                guard let caseDecl = enumMember.decl.as(EnumCaseDeclSyntax.self) else { continue }
                for element in caseDecl.elements {
                    // Use representedLiteralValue for raw values to correctly handle escapes.
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

    // MARK: - Type → JSONSchema expression

    private static func schemaExpression(
        for type: TypeSyntax,
        stringEnums: [String: [String]]
    ) -> (expr: String, isOptional: Bool) {

        // T? (postfix optional)
        if let optionalType = type.as(OptionalTypeSyntax.self) {
            let (inner, _) = schemaExpression(for: optionalType.wrappedType, stringEnums: stringEnums)
            return (inner, true)
        }

        // Optional<T> (explicit generic)
        if let identType = type.as(IdentifierTypeSyntax.self),
           identType.name.text == "Optional",
           let firstArg = identType.genericArgumentClause?.arguments.first {
            let (inner, _) = schemaExpression(for: firstArg.argument, stringEnums: stringEnums)
            return (inner, true)
        }

        // [Element]
        if let arrayType = type.as(ArrayTypeSyntax.self) {
            let (itemExpr, _) = schemaExpression(for: arrayType.element, stringEnums: stringEnums)
            return (".array(items: \(itemExpr))", false)
        }

        // [Key: Value] dictionary — represented as an open object schema.
        // We only handle [String: Value] since JSON keys must be strings.
        if let dictType = type.as(DictionaryTypeSyntax.self) {
            let keyName = dictType.key.trimmedDescription
            if keyName == "String" {
                let (valueExpr, _) = schemaExpression(for: dictType.value, stringEnums: stringEnums)
                // Use additionalProperties pattern: open object where all values share a schema.
                // The closest standard representation is an object with no fixed properties
                // but with a well-known value type expressed via a description.
                _ = valueExpr  // captured for documentation purposes
                return (".object(properties: [:], additionalProperties: true)", false)
            }
            // Non-string key dictionaries are not representable in JSON Schema.
            return (".object()", false)
        }

        // Named type
        if let identType = type.as(IdentifierTypeSyntax.self) {
            let name = identType.name.text

            // #19 — String enum: generate enumValues
            if let cases = stringEnums[name] {
                let quoted = cases.map { "\"\($0)\"" }.joined(separator: ", ")
                return (".string(enumValues: [\(quoted)])", false)
            }

            return (schemaForNamedType(name), false)
        }

        return (".object()", false)
    }

    private static func schemaForNamedType(_ name: String) -> String {
        switch name {
        case "String":                                          return ".string()"
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
