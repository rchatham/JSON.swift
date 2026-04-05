//
//  JSON.swift
//
//  Created by Reid Chatham on 2/10/25.
//

import Foundation

// MARK: - JSON

/// A type-safe representation of any JSON value.
///
/// `JSON` supports all standard JSON types: strings, numbers, booleans,
/// objects (dictionaries), arrays, and null. It conforms to `Codable` for
/// easy serialization and deserialization, and provides convenient subscript
/// access and literal initialization.
///
/// ```swift
/// // Create from literals
/// let name: JSON = "Alice"
/// let age: JSON = 30
/// let active: JSON = true
///
/// // Create complex structures
/// let user: JSON = [
///     "name": "Alice",
///     "age": 30,
///     "tags": ["swift", "developer"]
/// ]
///
/// // Access values
/// let userName = user["name"]?.stringValue  // "Alice"
/// let firstTag = user["tags"]?[0]?.stringValue  // "swift"
///
/// // Decode from JSON string
/// let json = try JSON(string: #"{"key": "value"}"#)
/// ```
@dynamicMemberLookup
public enum JSON: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSON])
    case array([JSON])
    case null

    // MARK: Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        // Try Bool before number — JSONDecoder can decode Bool as number
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
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

// MARK: - Convenience Initializers

extension JSON {
    /// Creates a `JSON` value by parsing a JSON string.
    ///
    /// - Parameter string: A UTF-8 encoded JSON string.
    /// - Throws: `JSONError.invalidValue` if the string cannot be converted to data,
    ///   or a `DecodingError` if parsing fails.
    public init(string: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw JSONError.invalidValue("Unable to convert string to UTF-8 data")
        }
        try self.init(data: data)
    }

    /// Creates a `JSON` value by decoding a `Data` instance.
    ///
    /// - Parameter data: JSON-encoded data.
    /// - Throws: A `DecodingError` if decoding fails.
    public init(data: Data) throws {
        let decoder = JSONDecoder()
        self = try decoder.decode(JSON.self, from: data)
    }

    /// Creates a `JSON` value from an untyped value.
    ///
    /// Supports `String`, `Double`, `Int`, `Float`, `Bool`, `[Any?]`,
    /// `[String: Any?]`, and `nil`.
    ///
    /// - Parameter value: The value to convert.
    /// - Throws: `JSONError.unsupportedType` if the value type is not supported.
    public init(_ value: Any?) throws {
        if value == nil || value is NSNull {
            self = .null
            return
        }

        switch value {
        case let string as String:
            self = .string(string)
        case let bool as Bool:
            self = .bool(bool)
        case let number as Double:
            self = .number(number)
        case let number as Int:
            self = .number(Double(number))
        case let number as Float:
            self = .number(Double(number))
        case let array as [Any?]:
            self = .array(try array.map { try JSON($0) })
        case let dict as [String: Any?]:
            var jsonDict: [String: JSON] = [:]
            for (key, val) in dict {
                jsonDict[key] = try JSON(val)
            }
            self = .object(jsonDict)
        default:
            throw JSONError.unsupportedType(String(describing: type(of: value)))
        }
    }

    /// Encodes a `Codable` value to `JSON`.
    ///
    /// - Parameter encodable: A value conforming to `Encodable`.
    /// - Throws: An encoding or decoding error.
    public init<T: Encodable>(encoding encodable: T) throws {
        let data = try JSONEncoder().encode(encodable)
        try self.init(data: data)
    }
}

// MARK: - Value Extraction

extension JSON {
    /// The string value if this is a `.string`, otherwise `nil`.
    public var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    /// The double value if this is a `.number`, otherwise `nil`.
    public var doubleValue: Double? {
        guard case .number(let value) = self else { return nil }
        return value
    }

    /// The integer value if this is a `.number`, otherwise `nil`.
    /// The double is converted to `Int` via truncation.
    public var intValue: Int? {
        guard case .number(let value) = self else { return nil }
        return Int(value)
    }

    /// The boolean value if this is a `.bool`, otherwise `nil`.
    public var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }

    /// The array value if this is an `.array`, otherwise `nil`.
    public var arrayValue: [JSON]? {
        guard case .array(let value) = self else { return nil }
        return value
    }

    /// The dictionary value if this is an `.object`, otherwise `nil`.
    public var objectValue: [String: JSON]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    /// Returns `true` if this is `.null`.
    public var isNull: Bool {
        guard case .null = self else { return false }
        return true
    }

    /// The number of elements in an array or object, or `nil` for other types.
    public var count: Int? {
        switch self {
        case .array(let arr): return arr.count
        case .object(let obj): return obj.count
        default: return nil
        }
    }

    /// A pretty-printed JSON string representation, or `nil` if encoding fails.
    public var jsonString: String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// A compact JSON string representation (no whitespace), or `nil` if encoding fails.
    public var compactJSONString: String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Decodes this JSON value into a `Decodable` type.
    ///
    /// ```swift
    /// let json: JSON = ["name": "Alice", "age": 30]
    /// let user: User = try json.decode(User.self)
    /// ```
    ///
    /// - Parameter type: The type to decode into.
    /// - Returns: The decoded value.
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let data = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Subscript Access

extension JSON {
    /// Accesses the value for a given key in a JSON object.
    ///
    /// Returns `nil` if the receiver is not an object or if the key is absent.
    /// Setting a value mutates the underlying object dictionary.
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

    /// Accesses the value at a given index in a JSON array.
    ///
    /// Returns `nil` if the receiver is not an array or the index is out of bounds.
    /// Setting a value mutates the underlying array.
    public subscript(index: Int) -> JSON? {
        get {
            guard case .array(let array) = self else { return nil }
            guard index >= 0 && index < array.count else { return nil }
            return array[index]
        }
        set {
            guard case .array(var array) = self else { return }
            guard index >= 0 && index < array.count else { return }
            if let newValue {
                array[index] = newValue
            } else {
                array.remove(at: index)
            }
            self = .array(array)
        }
    }

    /// Accesses object values via dynamic member lookup.
    ///
    /// ```swift
    /// let json: JSON = ["name": "Alice"]
    /// let name = json.name?.stringValue  // "Alice"
    /// ```
    public subscript(dynamicMember member: String) -> JSON? {
        get { self[member] }
        set { self[member] = newValue }
    }
}

// MARK: - Merge

extension JSON {
    /// Returns a new JSON value by merging another JSON value into this one.
    ///
    /// When both values are objects, their keys are merged recursively.
    /// For all other cases, the `other` value takes precedence.
    ///
    /// - Parameter other: The JSON value to merge in.
    /// - Returns: The merged JSON value.
    public func merging(_ other: JSON) -> JSON {
        switch (self, other) {
        case (.object(let lhs), .object(let rhs)):
            var merged = lhs
            for (key, value) in rhs {
                if let existing = merged[key] {
                    merged[key] = existing.merging(value)
                } else {
                    merged[key] = value
                }
            }
            return .object(merged)
        default:
            return other
        }
    }

    /// Merges another JSON value into this one in place.
    ///
    /// - Parameter other: The JSON value to merge in.
    public mutating func merge(_ other: JSON) {
        self = self.merging(other)
    }
}

// MARK: - JSONError

/// Errors that can occur during JSON operations.
public enum JSONError: Error, LocalizedError, Sendable {
    /// The value type is not supported for JSON conversion.
    case unsupportedType(String)
    /// The provided value is invalid.
    case invalidValue(String)
    /// The specified key was not found in a JSON object.
    case keyNotFound(String)
    /// The specified index was out of bounds for a JSON array.
    case indexOutOfBounds(Int)

    public var errorDescription: String? {
        switch self {
        case .unsupportedType(let type):
            return "Unsupported JSON type: \(type)"
        case .invalidValue(let message):
            return "Invalid JSON value: \(message)"
        case .keyNotFound(let key):
            return "Key not found: \(key)"
        case .indexOutOfBounds(let index):
            return "Index out of bounds: \(index)"
        }
    }
}

// MARK: - JSONSerialization-Compatible Conversion

extension JSON {
    /// Converts this JSON value to a Foundation-compatible type suitable for `JSONSerialization`.
    public var jsonCompatible: any Sendable {
        switch self {
        case .string(let value): return value
        case .number(let value): return value
        case .bool(let value): return value
        case .object(let value): return value.mapValues { $0.jsonCompatible }
        case .array(let value): return value.map { $0.jsonCompatible }
        case .null: return NSNull()
        }
    }
}

// MARK: - Dictionary Extension

extension Dictionary where Key == String, Value == JSON {
    /// A pretty-printed JSON string representation of this dictionary.
    public var string: String? {
        let jsonCompatibleDict = self.mapValues { $0.jsonCompatible }
        return (try? JSONSerialization.data(withJSONObject: jsonCompatibleDict, options: [.fragmentsAllowed, .prettyPrinted]))
            .flatMap { String(data: $0, encoding: .utf8) }
    }
}

// MARK: - ExpressibleByLiteral Conformances

extension JSON: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension JSON: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .number(Double(value))
    }
}

extension JSON: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .number(value)
    }
}

extension JSON: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension JSON: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSON...) {
        self = .array(elements)
    }
}

extension JSON: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSON)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}

extension JSON: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

// MARK: - CustomStringConvertible / CustomDebugStringConvertible

extension JSON: CustomStringConvertible {
    public var description: String {
        jsonString ?? "JSON(\(self))"
    }
}

extension JSON: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .string(let s): return "JSON.string(\"\(s)\")"
        case .number(let n): return "JSON.number(\(n))"
        case .bool(let b): return "JSON.bool(\(b))"
        case .object(let o): return "JSON.object(\(o.count) keys)"
        case .array(let a): return "JSON.array(\(a.count) elements)"
        case .null: return "JSON.null"
        }
    }
}
