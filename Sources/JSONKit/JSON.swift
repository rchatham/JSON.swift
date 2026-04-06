//
//  JSON.swift
//  JSONKit
//
//  Created by Reid Chatham on 2/10/25.
//

import Foundation

/// A type-safe representation of any JSON value.
///
/// `JSON` is a recursive enum that can represent any valid JSON value:
/// strings, numbers, booleans, null, arrays, and objects.
///
/// It supports full `Codable`, `Equatable`, `Hashable`, and `Sendable`
/// conformance and can be constructed directly from Swift literals.
///
/// ```swift
/// let json: JSON = [
///     "name": "Alice",
///     "age": 30,
///     "active": true
/// ]
/// print(json.name?.stringValue)   // Optional("Alice")  — dynamicMemberLookup
/// print(json["age"]?.intValue)    // Optional(30)       — subscript
/// ```
@dynamicMemberLookup
public enum JSON: Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSON])
    case array([JSON])
    case null
}

// MARK: - Codable

extension JSON: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        // Bool MUST be tried before Double: on Foundation's JSONDecoder,
        // `true`/`false` decode successfully as Double (1.0/0.0) if Bool
        // is attempted after Double, corrupting the value.
        if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
            return
        }

        if let number = try? container.decode(Double.self) {
            self = .number(number)
            return
        }

        if let string = try? container.decode(String.self) {
            self = .string(string)
            return
        }

        if let object = try? container.decode([String: JSON].self) {
            self = .object(object)
            return
        }

        if let array = try? container.decode([JSON].self) {
            self = .array(array)
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unable to decode JSON value"
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .number(let v): try container.encode(v)
        case .bool(let v):   try container.encode(v)
        case .object(let v): try container.encode(v)
        case .array(let v):  try container.encode(v)
        case .null:          try container.encodeNil()
        }
    }
}

// MARK: - Equatable

extension JSON: Equatable {
    public static func == (lhs: JSON, rhs: JSON) -> Bool {
        switch (lhs, rhs) {
        case (.string(let l), .string(let r)): return l == r
        case (.number(let l), .number(let r)): return l == r
        case (.bool(let l),   .bool(let r)):   return l == r
        case (.object(let l), .object(let r)): return l == r
        case (.array(let l),  .array(let r)):  return l == r
        case (.null,          .null):          return true
        default: return false
        }
    }
}

// MARK: - Hashable

extension JSON: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .string(let v): hasher.combine(0); hasher.combine(v)
        case .number(let v): hasher.combine(1); hasher.combine(v)
        case .bool(let v):   hasher.combine(2); hasher.combine(v)
        case .object(let v): hasher.combine(3); hasher.combine(v)
        case .array(let v):  hasher.combine(4); hasher.combine(v)
        case .null:          hasher.combine(5)
        }
    }
}

// MARK: - Convenience Initializers

extension JSON {
    /// Parses a JSON string into a `JSON` value.
    public init(string: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw JSONError.invalidValue("Unable to convert string to UTF-8 data")
        }
        try self.init(data: data)
    }

    /// Decodes a `JSON` value from raw `Data`.
    public init(data: Data) throws {
        self = try JSONDecoder().decode(JSON.self, from: data)
    }

    /// Bridges an `Any` value (e.g. from `JSONSerialization`) to `JSON`.
    ///
    /// Supported Swift types: `String`, `Double`, `Float`, `Int`, `Int32`, `Int64`,
    /// `Bool`, `[Any]`, `[String: Any]`, `NSNull`, and `nil` (via `Optional<Any>`).
    public init(_ value: Any) throws {
        switch value {
        case is NSNull:
            self = .null
        case let opt as AnyOptionalProtocol where opt.isNil:
            self = .null
        case let string as String:
            self = .string(string)
        case let number as Double:
            self = .number(number)
        case let number as Float:
            self = .number(Double(number))
        case let number as Int:
            self = .number(Double(number))
        case let number as Int64:
            self = .number(Double(number))
        case let number as Int32:
            self = .number(Double(number))
        case let bool as Bool:
            self = .bool(bool)
        case let array as [Any]:
            self = .array(try array.map { try JSON($0) })
        case let dict as [String: Any]:
            var jsonDict: [String: JSON] = [:]
            for (key, val) in dict { jsonDict[key] = try JSON(val) }
            self = .object(jsonDict)
        default:
            throw JSONError.unsupportedType(String(describing: type(of: value)))
        }
    }
}

// Internal helper for detecting Optional<T> erased to Any
private protocol AnyOptionalProtocol {
    var isNil: Bool { get }
}
extension Optional: AnyOptionalProtocol {
    var isNil: Bool { self == nil }
}

// MARK: - Value Extraction

extension JSON {
    /// The associated `String` value, or `nil` if this is not a `.string`.
    public var stringValue: String? {
        guard case .string(let v) = self else { return nil }
        return v
    }

    /// The associated `Double` value, or `nil` if this is not a `.number`.
    public var doubleValue: Double? {
        guard case .number(let v) = self else { return nil }
        return v
    }

    /// The exact integer value of the number, or `nil` if this is not a `.number`
    /// or the value has a fractional part (use `truncatedIntValue` if you want truncation).
    public var intValue: Int? {
        guard case .number(let v) = self else { return nil }
        return Int(exactly: v)
    }

    /// The integer value of the number, truncating any fractional part.
    /// Returns `nil` if this is not a `.number`.
    public var truncatedIntValue: Int? {
        guard case .number(let v) = self else { return nil }
        return Int(v)
    }

    /// The associated `Bool` value, or `nil` if this is not a `.bool`.
    public var boolValue: Bool? {
        guard case .bool(let v) = self else { return nil }
        return v
    }

    /// The associated array, or `nil` if this is not an `.array`.
    public var arrayValue: [JSON]? {
        guard case .array(let v) = self else { return nil }
        return v
    }

    /// The associated object dictionary, or `nil` if this is not an `.object`.
    public var objectValue: [String: JSON]? {
        guard case .object(let v) = self else { return nil }
        return v
    }

    /// `true` when this value is `.null`.
    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    /// A pretty-printed JSON string. Returns `nil` only if encoding fails unexpectedly.
    public var jsonString: String? {
        (try? JSON.encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) }
    }

    // Shared encoder — avoids allocating a new JSONEncoder on every call.
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
}

// MARK: - Throwing Value Access

extension JSON {
    /// Returns the value for `key`, throwing `JSONError.keyNotFound` if absent.
    public func value(forKey key: String) throws -> JSON {
        guard case .object(let dict) = self else {
            throw JSONError.typeMismatch(expected: "object", got: self)
        }
        guard let value = dict[key] else {
            throw JSONError.keyNotFound(key)
        }
        return value
    }

    /// Returns the element at `index`, throwing `JSONError.indexOutOfBounds` if out of range.
    public func value(at index: Int) throws -> JSON {
        guard case .array(let array) = self else {
            throw JSONError.typeMismatch(expected: "array", got: self)
        }
        guard index >= 0, index < array.count else {
            throw JSONError.indexOutOfBounds(index)
        }
        return array[index]
    }
}

// MARK: - Subscript Access (Optional, non-throwing)

extension JSON {
    /// Reads or writes an object key. Read returns `nil` for missing keys or wrong type.
    public subscript(key: String) -> JSON? {
        get {
            guard case .object(let dict) = self else { return nil }
            return dict[key]
        }
        set {
            guard case .object(var dict) = self else { return }
            dict[key] = newValue
            self = .object(dict)
        }
    }

    /// Reads or writes an array element. Read returns `nil` for out-of-bounds or wrong type.
    public subscript(index: Int) -> JSON? {
        get {
            guard case .array(let array) = self, index >= 0, index < array.count else { return nil }
            return array[index]
        }
        set {
            guard case .array(var array) = self, let newValue,
                  index >= 0, index < array.count else { return }
            array[index] = newValue
            self = .array(array)
        }
    }

    /// `@dynamicMemberLookup` — allows `json.name` as a shorthand for `json["name"]`.
    public subscript(dynamicMember key: String) -> JSON? {
        get { self[key] }
        set { self[key] = newValue }
    }
}

// MARK: - JSONSerialization Bridge

extension JSON {
    /// Converts this value to a type compatible with `JSONSerialization`.
    public var jsonCompatible: Any {
        switch self {
        case .string(let v):  return v
        case .number(let v):  return v
        case .bool(let v):    return v
        case .object(let v):  return v.mapValues { $0.jsonCompatible }
        case .array(let v):   return v.map { $0.jsonCompatible }
        case .null:           return NSNull()
        }
    }
}

// MARK: - Dictionary Helper

extension Dictionary where Key == String, Value == JSON {
    /// Serializes the dictionary to a pretty-printed JSON string using `JSONEncoder`.
    ///
    /// Uses the same encoder path as `JSON.jsonString` for consistent output.
    public var jsonString: String? {
        JSON.object(self).jsonString
    }
}

// MARK: - ExpressibleBy Literals

extension JSON: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}

extension JSON: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self = .number(value) }
}

extension JSON: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
}

extension JSON: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension JSON: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSON...) { self = .array(elements) }
}

extension JSON: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSON)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}

extension JSON: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) { self = .null }
}

// MARK: - CustomStringConvertible / CustomDebugStringConvertible

extension JSON: CustomStringConvertible {
    public var description: String { jsonString ?? "<unserializable JSON>" }
}

extension JSON: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .string(let v):  return "JSON.string(\(v.debugDescription))"
        case .number(let v):  return "JSON.number(\(v))"
        case .bool(let v):    return "JSON.bool(\(v))"
        case .object:         return "JSON.object(\(description))"
        case .array:          return "JSON.array(\(description))"
        case .null:           return "JSON.null"
        }
    }
}

// MARK: - Errors

/// Errors thrown by `JSON` operations.
public enum JSONError: Error, LocalizedError, Equatable {
    case unsupportedType(String)
    case invalidValue(String)
    case keyNotFound(String)
    case indexOutOfBounds(Int)
    case typeMismatch(expected: String, got: JSON)

    public static func == (lhs: JSONError, rhs: JSONError) -> Bool {
        switch (lhs, rhs) {
        case (.unsupportedType(let l), .unsupportedType(let r)): return l == r
        case (.invalidValue(let l),    .invalidValue(let r)):    return l == r
        case (.keyNotFound(let l),     .keyNotFound(let r)):     return l == r
        case (.indexOutOfBounds(let l),.indexOutOfBounds(let r)):return l == r
        case (.typeMismatch(let le, let lg), .typeMismatch(let re, let rg)):
            return le == re && lg == rg
        default: return false
        }
    }

    public var errorDescription: String? {
        switch self {
        case .unsupportedType(let t):          return "Unsupported type: \(t)"
        case .invalidValue(let msg):           return "Invalid value: \(msg)"
        case .keyNotFound(let key):            return "Key not found: '\(key)'"
        case .indexOutOfBounds(let idx):       return "Index out of bounds: \(idx)"
        case .typeMismatch(let exp, let got):  return "Type mismatch: expected \(exp), got \(got.debugDescription)"
        }
    }
}
