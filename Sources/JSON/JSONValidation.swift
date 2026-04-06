//
//  JSONValidation.swift
//  JSON
//
//  Created by Reid Chatham on 4/6/25.
//

import Foundation

// MARK: - ValidationError

/// A structured error describing why a `JSON` value does not conform to a `JSONSchema`.
///
/// Each error carries the JSON path where validation failed (e.g. `"root.address.city"`)
/// and a human-readable reason.
public struct ValidationError: Error, LocalizedError, Equatable, Sendable {

    /// Dot-separated path from the root value to the failing node.
    /// `"root"` means the top-level value itself.
    public let path: String

    /// Description of the constraint that was violated.
    public let reason: String

    public init(path: String = "root", reason: String) {
        self.path = path
        self.reason = reason
    }

    public var errorDescription: String? { "\(path): \(reason)" }
}

// MARK: - ValidationResult

/// The outcome of validating a `JSON` value against a `JSONSchema`.
public enum ValidationResult: Sendable {
    /// The value satisfies all schema constraints.
    case valid

    /// The value violates one or more constraints. All violations are collected.
    case invalid([ValidationError])

    /// `true` when validation passed with zero errors.
    public var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    /// All collected errors, or an empty array if the result is `.valid`.
    public var errors: [ValidationError] {
        if case .invalid(let errs) = self { return errs }
        return []
    }
}

// MARK: - JSON → validate(against:)

extension JSON {

    // MARK: Throwing interface

    /// Validates this value against `schema`, throwing a `ValidationError` for the
    /// first violation found.
    ///
    /// - Throws: `ValidationError` if any constraint is violated.
    public func validate(against schema: JSONSchema) throws {
        let result = validationResult(against: schema)
        if case .invalid(let errors) = result, let first = errors.first {
            throw first
        }
    }

    /// Returns `true` if this value satisfies every constraint in `schema`.
    public func isValid(against schema: JSONSchema) -> Bool {
        validationResult(against: schema).isValid
    }

    // MARK: Full-result interface

    /// Validates this value against `schema` and returns a `ValidationResult`
    /// containing **all** violations, not just the first.
    public func validationResult(against schema: JSONSchema) -> ValidationResult {
        var errors: [ValidationError] = []
        JSON.validate(value: self, schema: schema, path: "root", errors: &errors)
        return errors.isEmpty ? .valid : .invalid(errors)
    }

    // MARK: Core recursive validator

    private static func validate(
        value: JSON,
        schema: JSONSchema,
        path: String,
        errors: inout [ValidationError]
    ) {
        // --- anyOf -------------------------------------------------------
        if let anyOf = schema.anyOf {
            let matchCount = anyOf.filter { sub in
                var subErrors: [ValidationError] = []
                validate(value: value, schema: sub, path: path, errors: &subErrors)
                return subErrors.isEmpty
            }.count
            if matchCount == 0 {
                errors.append(ValidationError(
                    path: path,
                    reason: "value does not satisfy any of the \(anyOf.count) anyOf schemas"
                ))
            }
            return
        }

        // --- oneOf -------------------------------------------------------
        if let oneOf = schema.oneOf {
            let matching = oneOf.filter { sub in
                var subErrors: [ValidationError] = []
                validate(value: value, schema: sub, path: path, errors: &subErrors)
                return subErrors.isEmpty
            }
            if matching.count != 1 {
                errors.append(ValidationError(
                    path: path,
                    reason: "value must satisfy exactly one of the \(oneOf.count) oneOf schemas, but matched \(matching.count)"
                ))
            }
            return
        }

        // --- allOf -------------------------------------------------------
        if let allOf = schema.allOf {
            for (i, sub) in allOf.enumerated() {
                validate(value: value, schema: sub, path: "\(path)[allOf[\(i)]]", errors: &errors)
            }
            return
        }

        // --- type check --------------------------------------------------
        if let expectedType = schema.type {
            if !value.matches(type: expectedType) {
                errors.append(ValidationError(
                    path: path,
                    reason: "expected type '\(expectedType.rawValue)', got '\(value.typeName)'"
                ))
                // No point checking further constraints if the type is wrong.
                return
            }
        }

        // --- enum constraint (strings) -----------------------------------
        if let enumValues = schema.enumValues {
            if let str = value.stringValue, !enumValues.contains(str) {
                errors.append(ValidationError(
                    path: path,
                    reason: "'\(str)' is not one of the allowed values: \(enumValues.map { "\"\($0)\"" }.joined(separator: ", "))"
                ))
            }
        }

        // --- object ------------------------------------------------------
        if case .object(let dict) = value {
            // Required properties
            for key in schema.required ?? [] {
                if dict[key] == nil {
                    errors.append(ValidationError(
                        path: path,
                        reason: "missing required property '\(key)'"
                    ))
                }
            }

            // Additional properties
            if schema.additionalProperties == false,
               let knownKeys = schema.properties.map({ Set($0.keys) }) {
                for key in dict.keys where !knownKeys.contains(key) {
                    errors.append(ValidationError(
                        path: path,
                        reason: "additional property '\(key)' is not allowed"
                    ))
                }
            }

            // Recurse into defined properties
            if let propSchemas = schema.properties {
                for (key, propSchema) in propSchemas {
                    if let propValue = dict[key] {
                        validate(value: propValue, schema: propSchema,
                                 path: "\(path).\(key)", errors: &errors)
                    }
                    // Missing non-required properties are fine — already caught above.
                }
            }
        }

        // --- array -------------------------------------------------------
        if case .array(let elements) = value, let itemSchema = schema.items {
            for (i, element) in elements.enumerated() {
                validate(value: element, schema: itemSchema,
                         path: "\(path)[\(i)]", errors: &errors)
            }
        }
    }

    // MARK: Helpers

    fileprivate func matches(type schemaType: JSONSchema.SchemaType) -> Bool {
        switch schemaType {
        case .string:  return stringValue != nil
        case .number:  return doubleValue != nil
        case .integer:
            // An integer schema accepts whole-number doubles (e.g. 3.0) as well as exact ints.
            if case .number(let v) = self { return v == v.rounded() }
            return false
        case .boolean: return boolValue != nil
        case .null:    return isNull
        case .object:  return objectValue != nil
        case .array:   return arrayValue != nil
        }
    }

    fileprivate var typeName: String {
        switch self {
        case .string:  return "string"
        case .number:  return "number"
        case .bool:    return "boolean"
        case .object:  return "object"
        case .array:   return "array"
        case .null:    return "null"
        }
    }
}

// MARK: - JSONSchema → validate(_:)

extension JSONSchema {

    // MARK: Throwing interface

    /// Validates `value` against this schema, throwing the first `ValidationError` found.
    public func validate(_ value: JSON) throws {
        try value.validate(against: self)
    }

    /// Returns `true` if `value` satisfies every constraint in this schema.
    public func isValid(_ value: JSON) -> Bool {
        value.isValid(against: self)
    }

    // MARK: Full-result interface

    /// Validates `value` against this schema and returns a `ValidationResult`
    /// containing all violations.
    public func validationResult(for value: JSON) -> ValidationResult {
        value.validationResult(against: self)
    }
}

// MARK: - JSON → infer()

extension JSON {

    /// Infers a `JSONSchema` that describes the shape of this value.
    ///
    /// The inferred schema is a **structural snapshot** — it describes exactly
    /// what this value looks like, not a general schema that other values might
    /// also satisfy. Useful for:
    /// - Generating a starting-point schema for a known payload.
    /// - Comparing the structure of two JSON values.
    /// - Asserting that a decoded response matches an expected shape.
    ///
    /// ```swift
    /// let json: JSON = ["name": "Alice", "age": 30]
    /// let schema = json.inferredSchema()
    /// // → .object(properties: ["name": .string(), "age": .number()],
    /// //            required: ["name", "age"])
    /// ```
    public func inferredSchema() -> JSONSchema {
        switch self {
        case .string:
            return .string()
        case .number(let v):
            // Report as integer if the value has no fractional part.
            return v == v.rounded() ? .integer() : .number()
        case .bool:
            return .boolean()
        case .null:
            return .null()
        case .array(let elements):
            // Unify all element schemas; fall back to a permissive object if mixed.
            if elements.isEmpty {
                return .array(items: .object())
            }
            let itemSchemas = elements.map { $0.inferredSchema() }
            let unified = unifySchemas(itemSchemas)
            return .array(items: unified)
        case .object(let dict):
            var properties: [String: JSONSchema] = [:]
            for (key, val) in dict {
                properties[key] = val.inferredSchema()
            }
            return .object(
                properties: properties,
                required: Array(dict.keys).sorted(),
                additionalProperties: false
            )
        }
    }
}

// MARK: - JSONSchema → infer(from:)

extension JSONSchema {

    /// Derives a `JSONSchema` that describes the shape of `value`.
    ///
    /// Convenience wrapper around `JSON.inferredSchema()`.
    public static func infer(from value: JSON) -> JSONSchema {
        value.inferredSchema()
    }
}

// MARK: - Private: Schema Unification

/// Merges a collection of schemas into a single representative schema.
/// If all schemas share the same type, the type is preserved.
/// Otherwise an `anyOf` is returned to represent the union.
private func unifySchemas(_ schemas: [JSONSchema]) -> JSONSchema {
    guard !schemas.isEmpty else { return .object() }
    let uniqueTypes = Set(schemas.compactMap(\.type))

    // All same primitive type → use that type.
    if uniqueTypes.count == 1, let common = uniqueTypes.first {
        return JSONSchema(type: common)
    }

    // Mixed types → anyOf the distinct schemas (deduplicated).
    var seen: [JSONSchema] = []
    for s in schemas where !seen.contains(s) {
        seen.append(s)
    }
    return seen.count == 1 ? seen[0] : .anyOf(seen)
}
