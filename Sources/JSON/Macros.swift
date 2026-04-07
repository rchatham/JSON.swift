//
//  Macros.swift
//  JSON
//
//  Created by Reid Chatham on 4/5/25.
//

// MARK: - @JSONSchema Macro Declaration

/// Automatically synthesizes `JSONConvertible` or `JSONSchemaProviding` conformance.
///
/// When applied to a **struct**: generates `JSONConvertible` conformance with a `jsonSchema`
/// static property reflecting all stored properties, their types, and CodingKeys.
///
/// When applied to a **String raw-value enum**: generates `JSONSchemaProviding` conformance
/// with a `.string(enumValues: [...])` schema.
///
/// When applied to an **associated-value enum**: generates `JSONSchemaProviding` conformance
/// with a `.oneOf([...])` schema, one object schema per case.
///
/// Supported Swift property types and their schema mappings:
///
/// | Swift Type | Schema |
/// |---|---|
/// | `String` | `.string()` |
/// | `Int`, `Int32`, `Int64`, etc. | `.integer()` |
/// | `Double`, `Float`, `CGFloat`, `Decimal` | `.number()` |
/// | `Bool` | `.boolean()` |
/// | `Date` | `.string(description: "ISO 8601 date-time")` |
/// | `URL` | `.string(description: "URL")` |
/// | `UUID` | `.string(description: "UUID")` |
/// | `[Element]` | `.array(items: <element schema>)` |
/// | `Set<T>` | `.array(items: <element schema>, uniqueItems: true)` |
/// | `Optional<T>` | Same schema as `T`, excluded from `required` |
/// | Properties with default values | Same schema, excluded from `required` |
/// | Nested `enum` with `String` raw values | `.string(enumValues: [...])` |
/// | Any other named type | `.from(T.self)` |
///
/// **Struct usage**
/// ```swift
/// /// A registered user.
/// @JSONSchema
/// struct Person: Codable {
///     /// The user's full name.
///     let name: String
///     let age: Int
///     let email: String?        // optional → excluded from required[]
///     var nickname = "friend"   // has default → excluded from required[]
///
///     enum Status: String, Codable { case active, inactive }
///     let status: Status        // → .string(enumValues: ["active", "inactive"])
/// }
/// ```
///
/// **Enum usage**
/// ```swift
/// @JSONSchema
/// enum Color: String, Codable { case red, green, blue }
/// // → .string(enumValues: ["red", "green", "blue"])
/// ```
@attached(extension, conformances: JSONConvertible, JSONSchemaProviding, names: named(jsonSchema))
public macro JSONSchema() = #externalMacro(module: "JSONMacroPlugin", type: "JSONConvertibleMacro")
