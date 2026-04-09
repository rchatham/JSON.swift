//
//  JSON.swift
//  JSON
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

    /// Encodes any `Encodable` value to `JSON` in a single step.
    ///
    /// Uses `JSONValueEncoder` to walk the value tree directly — no intermediate `Data`
    /// allocation is required. For custom date/key strategies, use `init(encoding:encoder:)`.
    ///
    /// ```swift
    /// struct Point: Encodable { let x: Double; let y: Double }
    /// let json = try JSON(encoding: Point(x: 1, y: 2))
    /// // → .object(["x": .number(1.0), "y": .number(2.0)])
    /// ```
    public init<T: Encodable>(encoding value: T) throws {
        self = try JSONValueEncoder().encode(value)
    }

    /// Bridges an `Any` value (e.g. from `JSONSerialization`) to `JSON`.
    ///
    /// Supported Swift types: `String`, `Double`, `Float`, `Int`, `Int32`, `Int64`,
    /// `Bool`, `[Any]`, `[String: Any]`, `NSNull`, and `nil` (via `Optional<Any>`).
    ///
    /// - Note: `Bool` is tested **before** numeric types because on Apple platforms
    ///   a Swift `Bool` can be cast to `Double` (yielding `1.0`/`0.0`), which would
    ///   silently corrupt boolean values if the order were reversed.
    public init(_ value: Any) throws {
        switch value {
        case is NSNull:
            self = .null
        case let opt as AnyOptionalProtocol where opt.isNil:
            self = .null
        case let string as String:
            self = .string(string)
        // Bool MUST come before Double: on Apple platforms `Bool` satisfies `as Double`,
        // so casting to Double first would turn `true`/`false` into `1.0`/`0.0`.
        case let bool as Bool:
            self = .bool(bool)
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

    /// A pretty-printed, key-sorted JSON string.
    /// Returns `nil` only if encoding fails unexpectedly.
    public var jsonString: String? {
        jsonString()
    }

    /// Serializes this value to a JSON string with the given output formatting options.
    ///
    /// ```swift
    /// let compact = json.jsonString(formatting: [])         // no whitespace
    /// let pretty  = json.jsonString(formatting: .prettyPrinted)
    /// ```
    ///
    /// - Parameter formatting: The `JSONEncoder.OutputFormatting` options to use.
    ///   Defaults to `[.prettyPrinted, .sortedKeys]`.
    public func jsonString(
        formatting: JSONEncoder.OutputFormatting = [.prettyPrinted, .sortedKeys]
    ) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = formatting
        return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// The raw UTF-8 JSON data (pretty-printed, sorted keys).
    /// Returns `nil` only if encoding fails unexpectedly.
    ///
    /// Prefer this over `jsonString` when you need `Data` directly, as it avoids
    /// the intermediate `String` allocation.
    public var jsonData: Data? {
        try? JSON.threadSafeEncode(self)
    }

    // MARK: - #8 Thread-safe shared encoder

    /// Encodes a value using the shared encoder, serialised behind a lock.
    internal static func threadSafeEncode<T: Encodable>(_ value: T) throws -> Data {
        _jsonEncoderLock.lock()
        defer { _jsonEncoderLock.unlock() }
        return try _jsonEncoderInstance.encode(value)
    }

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

    /// Reads a deeply-nested value using a dot-separated key path.
    ///
    /// Each component of the path is used as an object key. Array indices are not
    /// supported in the path string; use the `Int`-subscript for those.
    ///
    /// ```swift
    /// let json: JSON = ["user": ["address": ["city": "Portland"]]]
    /// json[keyPath: "user.address.city"]  // → .string("Portland")
    /// json[keyPath: "user.missing.key"]   // → nil
    /// ```
    public subscript(keyPath path: String) -> JSON? {
        get {
            path.split(separator: ".", omittingEmptySubsequences: true)
                .reduce(Optional(self)) { current, key in current?[String(key)] }
        }
        set {
            let components = path.split(separator: ".", omittingEmptySubsequences: true).map(String.init)
            guard !components.isEmpty else { return }
            self.set(newValue, atComponents: components)
        }
    }

    /// Recursive helper for the key-path setter.
    private mutating func set(_ value: JSON?, atComponents components: [String]) {
        guard let key = components.first else { return }
        if components.count == 1 {
            self[key] = value
        } else {
            var child = self[key] ?? .object([:])
            child.set(value, atComponents: Array(components.dropFirst()))
            self[key] = child
        }
    }
}

// MARK: - Sequence (array iteration)

extension JSON: Sequence {
    /// Iterates over the elements of an array JSON value.
    ///
    /// If this value is not an `.array`, the sequence is empty.
    ///
    /// ```swift
    /// let json: JSON = [1, 2, 3]
    /// for item in json { print(item) }
    /// ```
    public func makeIterator() -> IndexingIterator<[JSON]> {
        (arrayValue ?? []).makeIterator()
    }
}

// MARK: - Object Merging

extension JSON {
    /// Returns a new object by merging `other` into `self`.
    ///
    /// Keys in `other` overwrite keys in `self`. If either operand is not an
    /// `.object`, `self` is returned unchanged.
    ///
    /// ```swift
    /// let base: JSON  = ["name": "Alice", "role": "user"]
    /// let patch: JSON = ["role": "admin", "active": true]
    /// let merged = base.merging(patch)
    /// // → ["name": "Alice", "role": "admin", "active": true]
    /// ```
    public func merging(_ other: JSON) -> JSON {
        guard case .object(let lhs) = self,
              case .object(let rhs) = other else { return self }
        return .object(lhs.merging(rhs) { _, new in new })
    }

    /// Merges `other` into this object in place.
    ///
    /// Keys in `other` overwrite keys in `self`. No-op if either operand is not an `.object`.
    public mutating func merge(_ other: JSON) {
        self = merging(other)
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

// MARK: - CustomPlaygroundDisplayConvertible

#if canImport(ObjectiveC)
extension JSON: CustomPlaygroundDisplayConvertible {
    /// Returns the pretty-printed JSON string for Xcode Playground display.
    public var playgroundDescription: Any { jsonString ?? description }
}
#endif

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
public enum JSONError: Error, LocalizedError, Equatable, Sendable {
    case unsupportedType(String)
    case invalidValue(String)
    case keyNotFound(String)
    case indexOutOfBounds(Int)
    case typeMismatch(expected: String, got: JSON)
    /// An HTTP response with a non-2xx status code was received.
    ///
    /// - Parameters:
    ///   - statusCode: The HTTP status code (e.g. 404, 500).
    ///   - body: The parsed response body, if the server returned one.
    case httpError(statusCode: Int, body: JSON?)

    public static func == (lhs: JSONError, rhs: JSONError) -> Bool {
        switch (lhs, rhs) {
        case (.unsupportedType(let l), .unsupportedType(let r)): return l == r
        case (.invalidValue(let l),    .invalidValue(let r)):    return l == r
        case (.keyNotFound(let l),     .keyNotFound(let r)):     return l == r
        case (.indexOutOfBounds(let l),.indexOutOfBounds(let r)):return l == r
        case (.typeMismatch(let le, let lg), .typeMismatch(let re, let rg)):
            return le == re && lg == rg
        case (.httpError(let lc, let lb), .httpError(let rc, let rb)):
            return lc == rc && lb == rb
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
        case .httpError(let code, _):          return "HTTP error: status code \(code)"
        }
    }
}

// MARK: - #11 Constants

extension JSON {
    /// An empty JSON object: `{}`.
    public static let emptyObject: JSON = .object([:])

    /// An empty JSON array: `[]`.
    public static let emptyArray: JSON = .array([])
}

// MARK: - #1 Equality operators (Optional<JSON> vs primitives)

/// Compares an optional `JSON` value to a `String`.
public func == (lhs: JSON?, rhs: String) -> Bool { lhs?.stringValue == rhs }
public func == (lhs: String, rhs: JSON?) -> Bool { rhs == lhs }
public func != (lhs: JSON?, rhs: String) -> Bool { !(lhs == rhs) }
public func != (lhs: String, rhs: JSON?) -> Bool { !(rhs == lhs) }

/// Compares an optional `JSON` value to an `Int`.
public func == (lhs: JSON?, rhs: Int) -> Bool { lhs?.intValue == rhs }
public func == (lhs: Int, rhs: JSON?) -> Bool { rhs == lhs }
public func != (lhs: JSON?, rhs: Int) -> Bool { !(lhs == rhs) }
public func != (lhs: Int, rhs: JSON?) -> Bool { !(rhs == lhs) }

/// Compares an optional `JSON` value to a `Double`.
public func == (lhs: JSON?, rhs: Double) -> Bool { lhs?.doubleValue == rhs }
public func == (lhs: Double, rhs: JSON?) -> Bool { rhs == lhs }
public func != (lhs: JSON?, rhs: Double) -> Bool { !(lhs == rhs) }
public func != (lhs: Double, rhs: JSON?) -> Bool { !(rhs == lhs) }

/// Compares an optional `JSON` value to a `Bool`.
public func == (lhs: JSON?, rhs: Bool) -> Bool { lhs?.boolValue == rhs }
public func == (lhs: Bool, rhs: JSON?) -> Bool { rhs == lhs }
public func != (lhs: JSON?, rhs: Bool) -> Bool { !(lhs == rhs) }
public func != (lhs: Bool, rhs: JSON?) -> Bool { !(rhs == lhs) }

// MARK: - #1 Pattern matching (~=) for switch statements

/// Enables `case "active":` in a `switch json["status"]` statement.
public func ~= (pattern: String, value: JSON?) -> Bool { value == pattern }
/// Enables `case 42:` in a `switch json["count"]` statement.
public func ~= (pattern: Int, value: JSON?) -> Bool { value == pattern }
/// Enables `case 3.14:` in a `switch json["ratio"]` statement.
public func ~= (pattern: Double, value: JSON?) -> Bool { value == pattern }
/// Enables `case true:` in a `switch json["active"]` statement.
public func ~= (pattern: Bool, value: JSON?) -> Bool { value == pattern }

// MARK: - #2 Collection inspection

extension JSON {
    /// The number of elements in an array, the number of keys in an object, or 0 for primitives.
    public var count: Int {
        switch self {
        case .array(let a):  return a.count
        case .object(let o): return o.count
        default:             return 0
        }
    }

    /// `true` when this value is logically empty:
    /// - `.null` is always empty.
    /// - `.string("")` (the empty string) is empty; non-empty strings are not.
    /// - `.number` and `.bool` are never empty — they always carry a meaningful value.
    /// - `.array([])` and `.object([:])` are empty; non-empty collections are not.
    public var isEmpty: Bool {
        switch self {
        case .array(let a):  return a.isEmpty
        case .object(let o): return o.isEmpty
        case .null:          return true
        case .string(let s): return s.isEmpty
        case .number, .bool: return false
        }
    }

    /// The keys of an object JSON value, or `nil` if this is not an `.object`.
    public var keys: [String]? {
        guard case .object(let o) = self else { return nil }
        return Array(o.keys)
    }

    /// The values of an object JSON value, or `nil` if this is not an `.object`.
    public var values: [JSON]? {
        guard case .object(let o) = self else { return nil }
        return Array(o.values)
    }

    /// Returns `true` if this object contains `key`.
    /// Always returns `false` for non-object values.
    public func contains(key: String) -> Bool {
        guard case .object(let o) = self else { return false }
        return o[key] != nil
    }
}

// MARK: - #3 Array / Object mutations

extension JSON {
    /// Appends `element` to an array. No-op if this is not an `.array`.
    public mutating func append(_ element: JSON) {
        guard case .array(var a) = self else { return }
        a.append(element)
        self = .array(a)
    }

    /// Appends all elements of `newElements` to an array. No-op if this is not an `.array`.
    public mutating func append<S: Sequence>(contentsOf newElements: S) where S.Element == JSON {
        guard case .array(var a) = self else { return }
        a.append(contentsOf: newElements)
        self = .array(a)
    }

    /// Removes and returns the element at `index` from an array.
    /// No-op (returns `nil`) if this is not an `.array` or `index` is out of bounds.
    @discardableResult
    public mutating func remove(at index: Int) -> JSON? {
        guard case .array(var a) = self, index >= 0, index < a.count else { return nil }
        let removed = a.remove(at: index)
        self = .array(a)
        return removed
    }

    /// Removes the value for `key` from an object, returning it.
    /// Returns `nil` if this is not an `.object` or the key is absent.
    @discardableResult
    public mutating func removeValue(forKey key: String) -> JSON? {
        guard case .object(var o) = self else { return nil }
        let removed = o.removeValue(forKey: key)
        self = .object(o)
        return removed
    }
}

// MARK: - #4 Throwing typed accessors

extension JSON {
    /// Returns the associated `String`, or throws `JSONError.typeMismatch`.
    public func requireString() throws -> String {
        guard let v = stringValue else {
            throw JSONError.typeMismatch(expected: "string", got: self)
        }
        return v
    }

    /// Returns the associated integer value, or throws `JSONError.typeMismatch`.
    /// The number must be a whole number (no fractional part).
    public func requireInt() throws -> Int {
        guard let v = intValue else {
            throw JSONError.typeMismatch(expected: "integer", got: self)
        }
        return v
    }

    /// Returns the associated `Double` value, or throws `JSONError.typeMismatch`.
    public func requireDouble() throws -> Double {
        guard let v = doubleValue else {
            throw JSONError.typeMismatch(expected: "number", got: self)
        }
        return v
    }

    /// Returns the associated `Bool` value, or throws `JSONError.typeMismatch`.
    public func requireBool() throws -> Bool {
        guard let v = boolValue else {
            throw JSONError.typeMismatch(expected: "boolean", got: self)
        }
        return v
    }

    /// Returns the associated array, or throws `JSONError.typeMismatch`.
    public func requireArray() throws -> [JSON] {
        guard let v = arrayValue else {
            throw JSONError.typeMismatch(expected: "array", got: self)
        }
        return v
    }

    /// Returns the associated object dictionary, or throws `JSONError.typeMismatch`.
    public func requireObject() throws -> [String: JSON] {
        guard let v = objectValue else {
            throw JSONError.typeMismatch(expected: "object", got: self)
        }
        return v
    }
}

// MARK: - #5 Typed extraction with defaults

extension JSON {
    /// Returns the string value for `key`, or `defaultValue` if the key is absent or the value is not a string.
    public func string(forKey key: String, default defaultValue: String = "") -> String {
        self[key]?.stringValue ?? defaultValue
    }

    /// Returns the integer value for `key`, or `defaultValue` if absent or not an integer.
    public func int(forKey key: String, default defaultValue: Int = 0) -> Int {
        self[key]?.intValue ?? defaultValue
    }

    /// Returns the double value for `key`, or `defaultValue` if absent or not a number.
    public func double(forKey key: String, default defaultValue: Double = 0) -> Double {
        self[key]?.doubleValue ?? defaultValue
    }

    /// Returns the bool value for `key`, or `defaultValue` if absent or not a boolean.
    public func bool(forKey key: String, default defaultValue: Bool = false) -> Bool {
        self[key]?.boolValue ?? defaultValue
    }
}

// MARK: - #6 decode(as:) / #18 decode(as:decoder:)

extension JSON {
    /// Decodes this `JSON` value into a `Decodable` type using the direct `JSONValueDecoder`.
    ///
    /// This avoids a Data round-trip by walking the JSON tree directly.
    ///
    /// ```swift
    /// let person: Person = try json["user"]!.decode()
    /// ```
    public func decode<T: Decodable>(as type: T.Type = T.self) throws -> T {
        try JSONValueDecoder().decode(T.self, from: self)
    }

    /// Decodes this `JSON` value into a `Decodable` type using a custom `JSONDecoder`.
    ///
    /// When you need date strategies or other decoder options, pass your own decoder here.
    ///
    /// ```swift
    /// let decoder = JSONDecoder()
    /// decoder.dateDecodingStrategy = .iso8601
    /// let event: Event = try json.decode(as: Event.self, decoder: decoder)
    /// ```
    public func decode<T: Decodable>(as type: T.Type = T.self, decoder: JSONDecoder) throws -> T {
        let data = try JSONEncoder().encode(self)
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - #18 JSON(encoding:encoder:)

extension JSON {
    /// Encodes an `Encodable` value using a custom `JSONEncoder`, then wraps the result as `JSON`.
    ///
    /// ```swift
    /// let encoder = JSONEncoder()
    /// encoder.dateEncodingStrategy = .iso8601
    /// let json = try JSON(encoding: myEvent, encoder: encoder)
    /// ```
    public init<T: Encodable>(encoding value: T, encoder: JSONEncoder) throws {
        let data = try encoder.encode(value)
        try self.init(data: data)
    }
}

// MARK: - #8 Thread-safe shared encoder

private let _jsonEncoderLock = NSLock()
private let _jsonEncoderInstance: JSONEncoder = {
    let e = JSONEncoder()
    e.outputFormatting = [.prettyPrinted, .sortedKeys]
    return e
}()

// MARK: - #19 LosslessStringConvertible

extension JSON: LosslessStringConvertible {
    /// Parses a JSON string into a `JSON` value.
    ///
    /// This is the `LosslessStringConvertible` initializer — `JSON("42")` → `.number(42)`,
    /// `JSON("\"hello\"")` → `.string("hello")`, etc.
    ///
    /// Returns `nil` if the string is not valid JSON.
    public init?(_ description: String) {
        guard let data = description.data(using: .utf8),
              let value = try? JSONDecoder().decode(JSON.self, from: data) else {
            return nil
        }
        self = value
    }
}

// MARK: - #20 JSON Pointer (RFC 6901)

extension JSON {
    /// Accesses a value using an [RFC 6901](https://datatracker.ietf.org/doc/html/rfc6901) JSON Pointer.
    ///
    /// - Supports object keys and array indices.
    /// - `~1` is decoded as `/`; `~0` is decoded as `~` (per spec).
    ///
    /// ```swift
    /// let json: JSON = ["users": [["name": "Alice"], ["name": "Bob"]]]
    /// json[pointer: "/users/0/name"]  // → .string("Alice")
    /// json[pointer: "/users/1/name"]  // → .string("Bob")
    /// ```
    public subscript(pointer path: String) -> JSON? {
        get {
            guard path.hasPrefix("/") else {
                // Empty string means the whole document; anything else without "/" is invalid.
                return path.isEmpty ? self : nil
            }
            let tokens = path.dropFirst().split(separator: "/", omittingEmptySubsequences: false)
                .map { $0.replacingOccurrences(of: "~1", with: "/").replacingOccurrences(of: "~0", with: "~") }
            return tokens.reduce(Optional(self)) { current, token in
                guard let current else { return nil }
                switch current {
                case .object(let dict):
                    return dict[token]
                case .array(let arr):
                    guard let idx = Int(token), idx >= 0, idx < arr.count else { return nil }
                    return arr[idx]
                default:
                    return nil
                }
            }
        }
        set {
            guard path.hasPrefix("/") else { return }
            let tokens = path.dropFirst().split(separator: "/", omittingEmptySubsequences: false)
                .map { $0.replacingOccurrences(of: "~1", with: "/").replacingOccurrences(of: "~0", with: "~") }
            self.setPointer(newValue, tokens: tokens)
        }
    }

    private mutating func setPointer(_ value: JSON?, tokens: [String]) {
        guard let token = tokens.first else { return }
        let rest = Array(tokens.dropFirst())
        if rest.isEmpty {
            // Terminal: apply the write
            switch self {
            case .object(var dict):
                dict[token] = value
                self = .object(dict)
            case .array(var arr):
                if let idx = Int(token), idx >= 0, idx < arr.count {
                    if let value { arr[idx] = value } else { arr.remove(at: idx) }
                    self = .array(arr)
                }
            default: break
            }
        } else {
            switch self {
            case .object(var dict):
                var child = dict[token] ?? .object([:])
                child.setPointer(value, tokens: rest)
                dict[token] = child
                self = .object(dict)
            case .array(var arr):
                guard let idx = Int(token), idx >= 0, idx < arr.count else { return }
                var child = arr[idx]
                child.setPointer(value, tokens: rest)
                arr[idx] = child
                self = .array(arr)
            default: break
            }
        }
    }
}

// MARK: - #21 Comparable

extension JSON: Comparable {
    /// Cross-type ordering: null < bool < number < string < array < object.
    ///
    /// Within a type, natural ordering applies (alphabetical for strings, numeric for numbers, etc.).
    /// Arrays are compared element-by-element (lexicographic); objects compare their sorted key lists.
    public static func < (lhs: JSON, rhs: JSON) -> Bool {
        switch (lhs, rhs) {
        case (.null,          .null):          return false
        case (.null,          _):              return true
        case (_,              .null):          return false
        case (.bool(let l),   .bool(let r)):   return !l && r   // false < true
        case (.bool,          _):              return true
        case (_,              .bool):          return false
        case (.number(let l), .number(let r)): return l < r
        case (.number,        _):              return true
        case (_,              .number):        return false
        case (.string(let l), .string(let r)): return l < r
        case (.string,        _):              return true
        case (_,              .string):        return false
        case (.array(let l),  .array(let r)):  return l.lexicographicallyPrecedes(r)
        case (.array,         _):              return true
        case (_,              .array):         return false
        case (.object(let l), .object(let r)):
            return l.keys.sorted().lexicographicallyPrecedes(r.keys.sorted())
        }
    }
}

// MARK: - #22 CustomReflectable

extension JSON: CustomReflectable {
    /// Provides a structured mirror for LLDB / Xcode debugger display.
    public var customMirror: Mirror {
        switch self {
        case .string(let v):  return Mirror(self, children: ["string": v])
        case .number(let v):  return Mirror(self, children: ["number": v])
        case .bool(let v):    return Mirror(self, children: ["bool": v])
        case .object(let v):  return Mirror(self, children: v.map { ($0.key, $0.value as Any) }, displayStyle: .dictionary)
        case .array(let v):   return Mirror(self, unlabeledChildren: v, displayStyle: .collection)
        case .null:           return Mirror(self, children: ["null": "()" as Any])
        }
    }
}

// MARK: - #23 isInteger

extension JSON {
    /// `true` when this value is a `.number` with no fractional part (e.g. `3.0`, `42.0`).
    ///
    /// This is distinct from `intValue != nil` because `intValue` may fail for large doubles.
    public var isInteger: Bool {
        guard case .number(let v) = self else { return false }
        return v.truncatingRemainder(dividingBy: 1) == 0 && !v.isInfinite && !v.isNaN
    }
}

// MARK: - #12 Coercing accessors

extension JSON {
    /// Returns a string representation of any JSON value.
    ///
    /// - `.string("hello")` → `"hello"`
    /// - `.number(42.0)` → `"42.0"` (or `"42"` when integer)
    /// - `.bool(true)` → `"true"`
    /// - `.null` → `"null"`
    /// - `.array` / `.object` → the compact JSON string
    public var coercedString: String {
        switch self {
        case .string(let v):  return v
        case .number(let v):  return v == v.rounded() && !v.isInfinite ? String(Int(v)) : String(v)
        case .bool(let v):    return v ? "true" : "false"
        case .null:           return "null"
        default:              return jsonString(formatting: []) ?? description
        }
    }

    /// Coerces this value to a `Double`.
    ///
    /// - `.number(v)` → `v`
    /// - `.string("3.14")` → `3.14` (parsed)
    /// - `.bool(true)` → `1.0`, `.bool(false)` → `0.0`
    /// - Everything else → `nil`
    public var coercedDouble: Double? {
        switch self {
        case .number(let v):  return v
        case .string(let v):  return Double(v)
        case .bool(let v):    return v ? 1.0 : 0.0
        default:              return nil
        }
    }

    /// Coerces this value to a `Bool`.
    ///
    /// - `.bool(v)` → `v`
    /// - `.number(0)` → `false`, any other number → `true`
    /// - `.string("true"/"yes"/"1")` → `true`; `"false"/"no"/"0"` → `false`
    /// - Everything else → `nil`
    public var coercedBool: Bool? {
        switch self {
        case .bool(let v):   return v
        case .number(let v): return v != 0
        case .string(let v):
            switch v.lowercased() {
            case "true",  "yes", "1": return true
            case "false", "no",  "0": return false
            default: return nil
            }
        default: return nil
        }
    }

    /// Coerces this value to an `Int`.
    ///
    /// - `.number(v)` → `Int(v)` (truncates fractional part)
    /// - `.string("42")` → `42`
    /// - `.bool(true)` → `1`, `.bool(false)` → `0`
    /// - Everything else → `nil`
    public var coercedInt: Int? {
        switch self {
        case .number(let v):  return Int(exactly: v) ?? (v.isFinite ? Int(v) : nil)
        case .string(let v):  return Int(v)
        case .bool(let v):    return v ? 1 : 0
        default:              return nil
        }
    }
}

// MARK: - #32 Async fetch

extension JSON {
    /// Fetches and parses a JSON value from the given URL using `URLSession`.
    ///
    /// ```swift
    /// let json = try await JSON.fetch(from: URL(string: "https://api.example.com/data")!)
    /// ```
    ///
    /// - Parameters:
    ///   - url: The URL to fetch from.
    ///   - session: The `URLSession` to use. Defaults to `.shared`.
    /// - Throws: `JSONError.httpError` for non-2xx status codes; any networking or
    ///   JSON-parsing error otherwise.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public static func fetch(
        from url: URL,
        session: URLSession = .shared
    ) async throws -> JSON {
        let request = URLRequest(url: url)
        return try await fetch(request: request, session: session)
    }

    /// Fetches and parses a JSON value using a custom `URLRequest`.
    ///
    /// Use this variant when you need to set HTTP method, headers, or a request body
    /// (e.g. for POST/PUT endpoints).
    ///
    /// ```swift
    /// var request = URLRequest(url: url)
    /// request.httpMethod = "POST"
    /// request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    /// request.httpBody = try JSONEncoder().encode(payload)
    /// let response = try await JSON.fetch(request: request)
    /// ```
    ///
    /// - Parameters:
    ///   - request: The `URLRequest` to execute.
    ///   - session: The `URLSession` to use. Defaults to `.shared`.
    /// - Throws: `JSONError.httpError` for non-2xx status codes; any networking or
    ///   JSON-parsing error otherwise.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public static func fetch(
        request: URLRequest,
        session: URLSession = .shared
    ) async throws -> JSON {
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            throw JSONError.httpError(
                statusCode: http.statusCode,
                body: try? JSON(data: data)
            )
        }
        return try JSON(data: data)
    }
}
