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
            if let knownKeys = schema.properties.map({ Set($0.keys) }) {
                let restrictAdditional: Bool
                let additionalSchema: JSONSchema?
                switch schema.additionalProperties {
                case .bool(false): restrictAdditional = true;  additionalSchema = nil
                case .bool(true):  restrictAdditional = false; additionalSchema = nil
                case .schema(let s): restrictAdditional = false; additionalSchema = s
                case nil:          restrictAdditional = false; additionalSchema = nil
                }
                for key in dict.keys where !knownKeys.contains(key) {
                    if restrictAdditional {
                        errors.append(ValidationError(
                            path: path,
                            reason: "additional property '\(key)' is not allowed"
                        ))
                    } else if let addlSchema = additionalSchema, let val = dict[key] {
                        validate(value: val, schema: addlSchema,
                                 path: "\(path).\(key)", errors: &errors)
                    }
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

        // --- numeric constraints -----------------------------------------
        if let v = value.doubleValue {
            if let min = schema.minimum, v < min {
                errors.append(ValidationError(
                    path: path,
                    reason: "value \(v) is less than minimum \(min)"
                ))
            }
            if let max = schema.maximum, v > max {
                errors.append(ValidationError(
                    path: path,
                    reason: "value \(v) is greater than maximum \(max)"
                ))
            }
            if let exMin = schema.exclusiveMinimum, v <= exMin {
                errors.append(ValidationError(
                    path: path,
                    reason: "value \(v) must be greater than exclusiveMinimum \(exMin)"
                ))
            }
            if let exMax = schema.exclusiveMaximum, v >= exMax {
                errors.append(ValidationError(
                    path: path,
                    reason: "value \(v) must be less than exclusiveMaximum \(exMax)"
                ))
            }
        }

        // --- string constraints ------------------------------------------
        if let str = value.stringValue {
            let count = str.count
            if let minLen = schema.minLength, count < minLen {
                errors.append(ValidationError(
                    path: path,
                    reason: "string length \(count) is less than minLength \(minLen)"
                ))
            }
            if let maxLen = schema.maxLength, count > maxLen {
                errors.append(ValidationError(
                    path: path,
                    reason: "string length \(count) exceeds maxLength \(maxLen)"
                ))
            }
            if let pat = schema.pattern {
                let range = str.range(of: pat, options: .regularExpression)
                if range == nil {
                    errors.append(ValidationError(
                        path: path,
                        reason: "string does not match pattern '\(pat)'"
                    ))
                }
            }
        }

        // --- array -------------------------------------------------------
        if case .array(let elements) = value {
            if let itemSchema = schema.items {
                for (i, element) in elements.enumerated() {
                    validate(value: element, schema: itemSchema,
                             path: "\(path)[\(i)]", errors: &errors)
                }
            }
            if let minItems = schema.minItems, elements.count < minItems {
                errors.append(ValidationError(
                    path: path,
                    reason: "array has \(elements.count) items, minimum is \(minItems)"
                ))
            }
            if let maxItems = schema.maxItems, elements.count > maxItems {
                errors.append(ValidationError(
                    path: path,
                    reason: "array has \(elements.count) items, maximum is \(maxItems)"
                ))
            }
            if schema.uniqueItems == true {
                // #7 — O(n) using Set<JSON> instead of O(n²) linear scan.
                var seen = Set<JSON>()
                for element in elements {
                    if !seen.insert(element).inserted {
                        errors.append(ValidationError(
                            path: path,
                            reason: "array items must be unique"
                        ))
                        break
                    }
                }
            }
        }

        // --- #25 not ---------------------------------------------------
        if let notSchema = schema.not {
            var subErrors: [ValidationError] = []
            validate(value: value, schema: notSchema, path: path, errors: &subErrors)
            if subErrors.isEmpty {
                errors.append(ValidationError(
                    path: path,
                    reason: "value must not be valid against the 'not' schema"
                ))
            }
        }

        // --- #24 const -------------------------------------------------
        if let constValue = schema.const, value != constValue {
            errors.append(ValidationError(
                path: path,
                reason: "value must equal const \(constValue)"
            ))
        }

        // --- #13 format ------------------------------------------------
        if let fmt = schema.format, let str = value.stringValue {
            validateFormat(str, format: fmt, path: path, errors: &errors)
        }
    }

    // MARK: - #13 Format validation

    private static func validateFormat(
        _ string: String,
        format: JSONSchema.StringFormat,
        path: String,
        errors: inout [ValidationError]
    ) {
        switch format {
        case .email:
            // Simple RFC 5322-ish check: local@domain.tld
            let pattern = #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#
            if string.range(of: pattern, options: .regularExpression) == nil {
                errors.append(ValidationError(path: path, reason: "'\(string)' is not a valid email address"))
            }
        case .uri:
            if URL(string: string)?.scheme == nil {
                errors.append(ValidationError(path: path, reason: "'\(string)' is not a valid URI"))
            }
        case .uuid:
            if UUID(uuidString: string) == nil {
                errors.append(ValidationError(path: path, reason: "'\(string)' is not a valid UUID"))
            }
        case .dateTime:
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let formatter2 = ISO8601DateFormatter()
            formatter2.formatOptions = [.withInternetDateTime]
            if formatter.date(from: string) == nil && formatter2.date(from: string) == nil {
                errors.append(ValidationError(path: path, reason: "'\(string)' is not a valid ISO 8601 date-time"))
            }
        case .date:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if formatter.date(from: string) == nil {
                errors.append(ValidationError(path: path, reason: "'\(string)' is not a valid date (yyyy-MM-dd)"))
            }
        case .time:
            let pattern = #"^\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})?$"#
            if string.range(of: pattern, options: .regularExpression) == nil {
                errors.append(ValidationError(path: path, reason: "'\(string)' is not a valid time"))
            }
        case .hostname:
            let pattern = #"^(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]$"#
            if string.range(of: pattern, options: .regularExpression) == nil {
                errors.append(ValidationError(path: path, reason: "'\(string)' is not a valid hostname"))
            }
        case .ipv4:
            let parts = string.split(separator: ".", omittingEmptySubsequences: false)
            let valid = parts.count == 4 && parts.allSatisfy { Int($0).map { $0 >= 0 && $0 <= 255 } ?? false }
            if !valid {
                errors.append(ValidationError(path: path, reason: "'\(string)' is not a valid IPv4 address"))
            }
        case .ipv6:
            // Basic check: contains colons and no invalid characters
            let pattern = #"^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$"#
            if string.range(of: pattern, options: .regularExpression) == nil {
                errors.append(ValidationError(path: path, reason: "'\(string)' is not a valid IPv6 address"))
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

    var typeName: String {
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

// MARK: - #10 Validate against JSONSchemaProviding / JSONConvertible types

extension JSON {
    /// Returns `true` if this value satisfies the schema of the given `JSONSchemaProviding` type.
    ///
    /// ```swift
    /// json.isValid(as: Person.self)  // true / false
    /// ```
    public func isValid<T: JSONSchemaProviding>(as type: T.Type) -> Bool {
        isValid(against: T.jsonSchema)
    }

    /// Validates this value against the schema of the given `JSONSchemaProviding` type,
    /// throwing the first `ValidationError` found.
    public func validate<T: JSONSchemaProviding>(as type: T.Type) throws {
        try validate(against: T.jsonSchema)
    }

    /// Validates this value against the schema of the given `JSONSchemaProviding` type
    /// and returns a `ValidationResult` containing all violations.
    public func validationResult<T: JSONSchemaProviding>(as type: T.Type) -> ValidationResult {
        validationResult(against: T.jsonSchema)
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
                additionalProperties: .bool(false)
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
///
/// - If all schemas have the same type, the merged type is preserved.
/// - For `.object` schemas, property dictionaries are merged (union of all keys).
/// - For mixed types, an `anyOf` of the distinct schemas is returned.
private func unifySchemas(_ schemas: [JSONSchema]) -> JSONSchema {
    guard !schemas.isEmpty else { return .object() }
    let uniqueTypes = Set(schemas.compactMap(\.type))

    // All same primitive type → merge properties when object, otherwise use that type.
    if uniqueTypes.count == 1, let common = uniqueTypes.first {
        if common == .object {
            // Merge all property dictionaries. For keys that appear in multiple
            // schemas, use the first schema's definition (schemas are presumed uniform).
            var mergedProperties: [String: JSONSchema] = [:]
            for schema in schemas {
                for (key, propSchema) in schema.properties ?? [:] {
                    if mergedProperties[key] == nil {
                        mergedProperties[key] = propSchema
                    }
                }
            }
            let allRequired = schemas.compactMap(\.required).flatMap { $0 }
            // A key is required only if every object that has it marks it required.
            let requiredSet = allRequired.isEmpty ? nil : Array(Set(allRequired).filter { key in
                schemas.allSatisfy { $0.properties?[key] == nil || ($0.required?.contains(key) ?? false) }
            }).sorted()
            return .object(
                properties: mergedProperties,
                required: requiredSet?.isEmpty == true ? nil : requiredSet,
                additionalProperties: .bool(false)
            )
        }
        return JSONSchema(type: common)
    }

    // Mixed types → anyOf the distinct schemas (deduplicated).
    var seen: [JSONSchema] = []
    for s in schemas where !seen.contains(s) {
        seen.append(s)
    }
    return seen.count == 1 ? seen[0] : .anyOf(seen)
}

// MARK: - #30 Coercion Mode

/// The result of applying schema-driven coercion to a `JSON` value.
public struct CoercionResult: Sendable {
    /// The coerced value (may equal the original if no changes were needed).
    public let value: JSON

    /// Descriptions of every change that was applied.
    public let changes: [String]

    /// `true` when no changes were applied.
    public var isUnchanged: Bool { changes.isEmpty }
}

extension JSON {
    /// Attempts to coerce this value to conform to `schema`.
    ///
    /// Coercion rules applied (in order):
    /// 1. Apply `schema.default` when the value is `.null` and a default exists.
    /// 2. String → number: `"42"` → `.number(42)` when schema type is `.number` or `.integer`.
    /// 3. Number → string: `42.0` → `"42"` when schema type is `.string`.
    /// 4. Remove additional properties (when `additionalProperties == .bool(false)`).
    /// 5. Recurse into object properties and array items.
    ///
    /// - Returns: A `CoercionResult` containing the (possibly modified) value and a list of applied changes.
    public func coerced(to schema: JSONSchema) -> CoercionResult {
        var changes: [String] = []
        let coerced = applyCoercion(to: self, schema: schema, path: "root", changes: &changes)
        return CoercionResult(value: coerced, changes: changes)
    }
}

private func applyCoercion(
    to value: JSON,
    schema: JSONSchema,
    path: String,
    changes: inout [String]
) -> JSON {
    var result = value

    // Apply default when value is null
    if case .null = result, let def = schema.default {
        changes.append("\(path): applied default value \(def)")
        result = def
    }

    // Handle anyOf by trying each branch and using the first that validates cleanly after coercion
    if let anyOf = schema.anyOf {
        for sub in anyOf {
            var subChanges: [String] = []
            let candidate = applyCoercion(to: result, schema: sub, path: path, changes: &subChanges)
            let validation = candidate.validationResult(against: sub)
            if validation.isValid {
                changes.append(contentsOf: subChanges)
                return candidate
            }
        }
        return result
    }

    guard let schemaType = schema.type else { return result }

    // Type coercions
    switch (schemaType, result) {
    case (.number, .string(let s)):
        if let d = Double(s) {
            changes.append("\(path): coerced string \"\(s)\" to number \(d)")
            result = .number(d)
        }
    case (.integer, .string(let s)):
        if let i = Int(s) {
            changes.append("\(path): coerced string \"\(s)\" to integer \(i)")
            result = .number(Double(i))
        }
    case (.string, .number(let n)):
        let str = n == n.rounded() && !n.isInfinite ? String(Int(n)) : String(n)
        changes.append("\(path): coerced number \(n) to string \"\(str)\"")
        result = .string(str)
    case (.boolean, .string(let s)):
        if let b = ["true","yes","1"].contains(s.lowercased()) ? true : ["false","no","0"].contains(s.lowercased()) ? false : nil {
            changes.append("\(path): coerced string \"\(s)\" to boolean \(b)")
            result = .bool(b)
        }
    default: break
    }

    // Recurse into objects
    if case .object(var dict) = result, schemaType == .object {
        // Remove additional properties if restricted
        if schema.additionalProperties == .bool(false) {
            if let allowed = schema.properties.map({ Set($0.keys) }) {
                for key in dict.keys where !allowed.contains(key) {
                    dict.removeValue(forKey: key)
                    changes.append("\(path).\(key): removed additional property")
                }
            }
        }
        // Apply property defaults and recurse
        if let propSchemas = schema.properties {
            for (key, propSchema) in propSchemas {
                if dict[key] == nil, let def = propSchema.default {
                    dict[key] = def
                    changes.append("\(path).\(key): applied default \(def)")
                } else if let val = dict[key] {
                    var propChanges: [String] = []
                    dict[key] = applyCoercion(to: val, schema: propSchema, path: "\(path).\(key)", changes: &propChanges)
                    changes.append(contentsOf: propChanges)
                }
            }
        }
        result = .object(dict)
    }

    // Recurse into arrays
    if case .array(let elements) = result, schemaType == .array, let itemSchema = schema.items {
        let coerced = elements.enumerated().map { (i, el) -> JSON in
            var itemChanges: [String] = []
            let c = applyCoercion(to: el, schema: itemSchema, path: "\(path)[\(i)]", changes: &itemChanges)
            changes.append(contentsOf: itemChanges)
            return c
        }
        result = .array(coerced)
    }

    return result
}
