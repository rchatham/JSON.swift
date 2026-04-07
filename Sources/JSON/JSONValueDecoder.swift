//
//  JSONValueDecoder.swift
//  JSON
//
//  Created by Reid Chatham on 4/7/25.
//
//  A custom `Decoder` implementation that walks a `JSON` value tree directly,
//  without encoding to `Data` first. This avoids unnecessary allocations and
//  preserves full type fidelity (e.g. booleans are never confused with numbers).
//

import Foundation

// MARK: - JSONValueDecoder (top-level entry point)

/// A decoder that converts a `JSON` value into any `Decodable` type
/// without serialising to `Data` first.
///
/// ```swift
/// let person: Person = try JSONValueDecoder().decode(Person.self, from: json)
/// // — or via the convenience method —
/// let person: Person = try json.decode()
/// ```
public struct JSONValueDecoder {
    /// User-info dictionary forwarded to decoding containers.
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    public init() {}

    /// Decodes a `Decodable` value from a `JSON` value.
    public func decode<T: Decodable>(_ type: T.Type, from json: JSON) throws -> T {
        let decoder = _JSONDecoder(json: json, userInfo: userInfo)
        return try T(from: decoder)
    }
}

// MARK: - Internal Decoder

private final class _JSONDecoder: Decoder {
    let json: JSON
    let codingPath: [CodingKey]
    let userInfo: [CodingUserInfoKey: Any]

    init(json: JSON, codingPath: [CodingKey] = [], userInfo: [CodingUserInfoKey: Any] = [:]) {
        self.json = json
        self.codingPath = codingPath
        self.userInfo = userInfo
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard case .object(let dict) = json else {
            throw DecodingError.typeMismatch(
                [String: JSON].self,
                DecodingError.Context(codingPath: codingPath,
                                      debugDescription: "Expected object, got \(json.typeName)")
            )
        }
        return KeyedDecodingContainer(_KeyedContainer<Key>(dict: dict, codingPath: codingPath, userInfo: userInfo))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard case .array(let arr) = json else {
            throw DecodingError.typeMismatch(
                [JSON].self,
                DecodingError.Context(codingPath: codingPath,
                                      debugDescription: "Expected array, got \(json.typeName)")
            )
        }
        return _UnkeyedContainer(array: arr, codingPath: codingPath, userInfo: userInfo)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        _SingleValueContainer(json: json, codingPath: codingPath, userInfo: userInfo)
    }
}

// MARK: - Keyed Container

private struct _KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let dict: [String: JSON]
    let codingPath: [CodingKey]
    let userInfo: [CodingUserInfoKey: Any]

    var allKeys: [Key] { dict.keys.compactMap { Key(stringValue: $0) } }

    func contains(_ key: Key) -> Bool { dict[key.stringValue] != nil }

    private func require(_ key: Key) throws -> JSON {
        guard let value = dict[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(codingPath: codingPath,
                                      debugDescription: "Key '\(key.stringValue)' not found")
            )
        }
        return value
    }

    private func childDecoder(for key: Key, json: JSON) -> _JSONDecoder {
        _JSONDecoder(json: json, codingPath: codingPath + [key], userInfo: userInfo)
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        guard let v = dict[key.stringValue] else { return true }
        return v == .null
    }

    func decode(_ type: Bool.Type,   forKey key: Key) throws -> Bool   { try require(key).decodeBool(path: codingPath + [key]) }
    func decode(_ type: String.Type, forKey key: Key) throws -> String { try require(key).decodeString(path: codingPath + [key]) }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double { try require(key).decodeDouble(path: codingPath + [key]) }
    func decode(_ type: Float.Type,  forKey key: Key) throws -> Float  { Float(try require(key).decodeDouble(path: codingPath + [key])) }
    func decode(_ type: Int.Type,    forKey key: Key) throws -> Int    { try require(key).decodeInt(Int.self,   path: codingPath + [key]) }
    func decode(_ type: Int8.Type,   forKey key: Key) throws -> Int8   { try require(key).decodeInt(Int8.self,  path: codingPath + [key]) }
    func decode(_ type: Int16.Type,  forKey key: Key) throws -> Int16  { try require(key).decodeInt(Int16.self, path: codingPath + [key]) }
    func decode(_ type: Int32.Type,  forKey key: Key) throws -> Int32  { try require(key).decodeInt(Int32.self, path: codingPath + [key]) }
    func decode(_ type: Int64.Type,  forKey key: Key) throws -> Int64  { try require(key).decodeInt(Int64.self, path: codingPath + [key]) }
    func decode(_ type: UInt.Type,   forKey key: Key) throws -> UInt   { try require(key).decodeInt(UInt.self,   path: codingPath + [key]) }
    func decode(_ type: UInt8.Type,  forKey key: Key) throws -> UInt8  { try require(key).decodeInt(UInt8.self,  path: codingPath + [key]) }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { try require(key).decodeInt(UInt16.self, path: codingPath + [key]) }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { try require(key).decodeInt(UInt32.self, path: codingPath + [key]) }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { try require(key).decodeInt(UInt64.self, path: codingPath + [key]) }
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        try T(from: childDecoder(for: key, json: require(key)))
    }

    func nestedContainer<NK: CodingKey>(keyedBy type: NK.Type, forKey key: Key) throws -> KeyedDecodingContainer<NK> {
        try childDecoder(for: key, json: require(key)).container(keyedBy: NK.self)
    }
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        try childDecoder(for: key, json: require(key)).unkeyedContainer()
    }
    func superDecoder() throws -> Decoder { _JSONDecoder(json: .object(dict), codingPath: codingPath, userInfo: userInfo) }
    func superDecoder(forKey key: Key) throws -> Decoder { childDecoder(for: key, json: try require(key)) }
}

// MARK: - Unkeyed Container

private struct _UnkeyedContainer: UnkeyedDecodingContainer {
    let array: [JSON]
    let codingPath: [CodingKey]
    let userInfo: [CodingUserInfoKey: Any]
    var currentIndex: Int = 0

    var count: Int? { array.count }
    var isAtEnd: Bool { currentIndex >= array.count }

    private mutating func next(path: [CodingKey]) throws -> JSON {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                JSON.self,
                DecodingError.Context(codingPath: path, debugDescription: "Unkeyed container exhausted")
            )
        }
        let v = array[currentIndex]
        currentIndex += 1
        return v
    }

    private var currentPath: [CodingKey] { codingPath + [_IndexKey(intValue: currentIndex)] }

    mutating func decodeNil() throws -> Bool {
        if array[currentIndex] == .null { currentIndex += 1; return true }
        return false
    }

    mutating func decode(_ type: Bool.Type)   throws -> Bool   { try next(path: currentPath).decodeBool(path: currentPath) }
    mutating func decode(_ type: String.Type) throws -> String { try next(path: currentPath).decodeString(path: currentPath) }
    mutating func decode(_ type: Double.Type) throws -> Double { try next(path: currentPath).decodeDouble(path: currentPath) }
    mutating func decode(_ type: Float.Type)  throws -> Float  { Float(try next(path: currentPath).decodeDouble(path: currentPath)) }
    mutating func decode(_ type: Int.Type)    throws -> Int    { try next(path: currentPath).decodeInt(Int.self,   path: currentPath) }
    mutating func decode(_ type: Int8.Type)   throws -> Int8   { try next(path: currentPath).decodeInt(Int8.self,  path: currentPath) }
    mutating func decode(_ type: Int16.Type)  throws -> Int16  { try next(path: currentPath).decodeInt(Int16.self, path: currentPath) }
    mutating func decode(_ type: Int32.Type)  throws -> Int32  { try next(path: currentPath).decodeInt(Int32.self, path: currentPath) }
    mutating func decode(_ type: Int64.Type)  throws -> Int64  { try next(path: currentPath).decodeInt(Int64.self, path: currentPath) }
    mutating func decode(_ type: UInt.Type)   throws -> UInt   { try next(path: currentPath).decodeInt(UInt.self,   path: currentPath) }
    mutating func decode(_ type: UInt8.Type)  throws -> UInt8  { try next(path: currentPath).decodeInt(UInt8.self,  path: currentPath) }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { try next(path: currentPath).decodeInt(UInt16.self, path: currentPath) }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { try next(path: currentPath).decodeInt(UInt32.self, path: currentPath) }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 { try next(path: currentPath).decodeInt(UInt64.self, path: currentPath) }
    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let p = currentPath
        let v = try next(path: p)
        return try T(from: _JSONDecoder(json: v, codingPath: p, userInfo: userInfo))
    }

    mutating func nestedContainer<NK: CodingKey>(keyedBy type: NK.Type) throws -> KeyedDecodingContainer<NK> {
        let p = currentPath
        let v = try next(path: p)
        return try _JSONDecoder(json: v, codingPath: p, userInfo: userInfo).container(keyedBy: NK.self)
    }
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let p = currentPath
        let v = try next(path: p)
        return try _JSONDecoder(json: v, codingPath: p, userInfo: userInfo).unkeyedContainer()
    }
    mutating func superDecoder() throws -> Decoder {
        let p = currentPath
        let v = try next(path: p)
        return _JSONDecoder(json: v, codingPath: p, userInfo: userInfo)
    }
}

// MARK: - Single Value Container

private struct _SingleValueContainer: SingleValueDecodingContainer {
    let json: JSON
    let codingPath: [CodingKey]
    let userInfo: [CodingUserInfoKey: Any]

    func decodeNil() -> Bool { json == .null }
    func decode(_ type: Bool.Type)   throws -> Bool   { try json.decodeBool(path: codingPath) }
    func decode(_ type: String.Type) throws -> String { try json.decodeString(path: codingPath) }
    func decode(_ type: Double.Type) throws -> Double { try json.decodeDouble(path: codingPath) }
    func decode(_ type: Float.Type)  throws -> Float  { Float(try json.decodeDouble(path: codingPath)) }
    func decode(_ type: Int.Type)    throws -> Int    { try json.decodeInt(Int.self,   path: codingPath) }
    func decode(_ type: Int8.Type)   throws -> Int8   { try json.decodeInt(Int8.self,  path: codingPath) }
    func decode(_ type: Int16.Type)  throws -> Int16  { try json.decodeInt(Int16.self, path: codingPath) }
    func decode(_ type: Int32.Type)  throws -> Int32  { try json.decodeInt(Int32.self, path: codingPath) }
    func decode(_ type: Int64.Type)  throws -> Int64  { try json.decodeInt(Int64.self, path: codingPath) }
    func decode(_ type: UInt.Type)   throws -> UInt   { try json.decodeInt(UInt.self,   path: codingPath) }
    func decode(_ type: UInt8.Type)  throws -> UInt8  { try json.decodeInt(UInt8.self,  path: codingPath) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try json.decodeInt(UInt16.self, path: codingPath) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try json.decodeInt(UInt32.self, path: codingPath) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try json.decodeInt(UInt64.self, path: codingPath) }
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try T(from: _JSONDecoder(json: json, codingPath: codingPath, userInfo: userInfo))
    }
}

// MARK: - JSON primitive extraction helpers

private extension JSON {
    func decodeBool(path: [CodingKey]) throws -> Bool {
        guard case .bool(let v) = self else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: path, debugDescription: "Expected Bool, got \(typeName)")
            )
        }
        return v
    }

    func decodeString(path: [CodingKey]) throws -> String {
        guard case .string(let v) = self else {
            throw DecodingError.typeMismatch(
                String.self,
                DecodingError.Context(codingPath: path, debugDescription: "Expected String, got \(typeName)")
            )
        }
        return v
    }

    func decodeDouble(path: [CodingKey]) throws -> Double {
        guard case .number(let v) = self else {
            throw DecodingError.typeMismatch(
                Double.self,
                DecodingError.Context(codingPath: path, debugDescription: "Expected Number, got \(typeName)")
            )
        }
        return v
    }

    func decodeInt<T: BinaryInteger>(_ type: T.Type, path: [CodingKey]) throws -> T {
        guard case .number(let v) = self else {
            throw DecodingError.typeMismatch(
                T.self,
                DecodingError.Context(codingPath: path, debugDescription: "Expected Number, got \(typeName)")
            )
        }
        guard let result = T(exactly: v) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: path,
                                      debugDescription: "Number \(v) cannot be represented as \(T.self)")
            )
        }
        return result
    }
}

// MARK: - Index coding key helper

private struct _IndexKey: CodingKey {
    var intValue: Int?
    var stringValue: String { intValue.map(String.init) ?? "" }
    init(intValue: Int) { self.intValue = intValue }
    init?(stringValue: String) { guard let i = Int(stringValue) else { return nil }; intValue = i }
}
