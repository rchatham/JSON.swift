//
//  JSONValueEncoder.swift
//  JSON
//
//  Created by Reid Chatham on 4/7/25.
//
//  A custom `Encoder` implementation that builds a `JSON` value tree directly,
//  without serialising to `Data` first. This avoids unnecessary allocations and
//  is the complement to `JSONValueDecoder`.
//

import Foundation

// MARK: - JSONValueEncoder (public API)

/// An encoder that converts any `Encodable` value into a `JSON` value
/// without serialising to `Data` first.
///
/// ```swift
/// struct Point: Encodable { let x: Double; let y: Double }
/// let json = try JSONValueEncoder().encode(Point(x: 1, y: 2))
/// // → .object(["x": .number(1.0), "y": .number(2.0)])
/// ```
///
/// - Note: For custom `dateEncodingStrategy` or `keyEncodingStrategy`, use
///   `JSONEncoder` with `JSON(encoding:encoder:)` instead — those strategies are
///   applied by the Foundation encoder, not by `JSONValueEncoder`.
public struct JSONValueEncoder {
    /// User-info dictionary forwarded to all encoding containers.
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    public init() {}

    /// Encodes an `Encodable` value into a `JSON` value.
    public func encode<T: Encodable>(_ value: T) throws -> JSON {
        let impl = _JVEImpl(codingPath: [], userInfo: userInfo)
        try value.encode(to: impl)
        return impl.finalize()
    }
}

// MARK: - Internal box types (reference types that accumulate the JSON tree)

/// A dictionary box used by keyed containers.
private final class _JVEKeyedBox {
    var dict: [String: _JVEBox] = [:]
}

/// An array box used by unkeyed containers.
private final class _JVEUnkeyedBox {
    var array: [_JVEBox] = []
}

/// The internal representation built up during encoding.
/// Mirrors `JSON` but uses class-based containers so nested containers can be
/// written to after they are returned from `nestedContainer`/`nestedUnkeyedContainer`.
private enum _JVEBox {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case keyed(_JVEKeyedBox)
    case unkeyed(_JVEUnkeyedBox)

    /// Converts the accumulated box into a `JSON` value.
    var json: JSON {
        switch self {
        case .null:              return .null
        case .bool(let b):       return .bool(b)
        case .number(let n):     return .number(n)
        case .string(let s):     return .string(s)
        case .keyed(let box):    return .object(box.dict.mapValues { $0.json })
        case .unkeyed(let box):  return .array(box.array.map { $0.json })
        }
    }
}

// MARK: - Top-level encoder implementation

private final class _JVEImpl: Encoder {
    let codingPath: [CodingKey]
    let userInfo: [CodingUserInfoKey: Any]
    var result: _JVEBox?

    init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any]) {
        self.codingPath = codingPath
        self.userInfo   = userInfo
    }

    func finalize() -> JSON { result?.json ?? .null }

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        let box = _JVEKeyedBox()
        result  = .keyed(box)
        return KeyedEncodingContainer(
            _JVEKeyedContainer<Key>(box: box, codingPath: codingPath, userInfo: userInfo)
        )
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        let box = _JVEUnkeyedBox()
        result  = .unkeyed(box)
        return _JVEUnkeyedContainer(box: box, codingPath: codingPath, userInfo: userInfo)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        _JVESingleValueContainer(impl: self, codingPath: codingPath)
    }
}

// MARK: - Keyed container

private struct _JVEKeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let box: _JVEKeyedBox
    var codingPath: [CodingKey]
    let userInfo: [CodingUserInfoKey: Any]

    // MARK: Primitive writes
    mutating func encodeNil(forKey key: Key) throws { box.dict[key.stringValue] = .null }
    mutating func encode(_ v: Bool,   forKey key: Key) throws { box.dict[key.stringValue] = .bool(v) }
    mutating func encode(_ v: String, forKey key: Key) throws { box.dict[key.stringValue] = .string(v) }
    mutating func encode(_ v: Double, forKey key: Key) throws { box.dict[key.stringValue] = .number(v) }
    mutating func encode(_ v: Float,  forKey key: Key) throws { box.dict[key.stringValue] = .number(Double(v)) }
    mutating func encode(_ v: Int,    forKey key: Key) throws { box.dict[key.stringValue] = .number(Double(v)) }
    mutating func encode(_ v: Int8,   forKey key: Key) throws { box.dict[key.stringValue] = .number(Double(v)) }
    mutating func encode(_ v: Int16,  forKey key: Key) throws { box.dict[key.stringValue] = .number(Double(v)) }
    mutating func encode(_ v: Int32,  forKey key: Key) throws { box.dict[key.stringValue] = .number(Double(v)) }
    mutating func encode(_ v: Int64,  forKey key: Key) throws { box.dict[key.stringValue] = .number(Double(v)) }
    mutating func encode(_ v: UInt,   forKey key: Key) throws { box.dict[key.stringValue] = .number(Double(v)) }
    mutating func encode(_ v: UInt8,  forKey key: Key) throws { box.dict[key.stringValue] = .number(Double(v)) }
    mutating func encode(_ v: UInt16, forKey key: Key) throws { box.dict[key.stringValue] = .number(Double(v)) }
    mutating func encode(_ v: UInt32, forKey key: Key) throws { box.dict[key.stringValue] = .number(Double(v)) }
    mutating func encode(_ v: UInt64, forKey key: Key) throws { box.dict[key.stringValue] = .number(Double(v)) }

    // MARK: Generic Encodable write
    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        // Short-circuit for `JSON` values: convert directly without re-encoding.
        if let json = value as? JSON {
            box.dict[key.stringValue] = _boxFromJSON(json)
            return
        }
        let child = _JVEImpl(codingPath: codingPath + [key], userInfo: userInfo)
        try value.encode(to: child)
        box.dict[key.stringValue] = child.result ?? .null
    }

    // MARK: Nested containers
    mutating func nestedContainer<NK: CodingKey>(
        keyedBy keyType: NK.Type, forKey key: Key
    ) -> KeyedEncodingContainer<NK> {
        let childBox = _JVEKeyedBox()
        box.dict[key.stringValue] = .keyed(childBox)
        return KeyedEncodingContainer(
            _JVEKeyedContainer<NK>(box: childBox,
                                   codingPath: codingPath + [key],
                                   userInfo: userInfo)
        )
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let childBox = _JVEUnkeyedBox()
        box.dict[key.stringValue] = .unkeyed(childBox)
        return _JVEUnkeyedContainer(box: childBox,
                                    codingPath: codingPath + [key],
                                    userInfo: userInfo)
    }

    // MARK: Super encoders
    // `superEncoder` is used by synthesised class-hierarchy Codable implementations.
    // We return a child encoder; its result is stored at the "super" key so the
    // data isn't silently lost (best-effort — synchronous encoding is assumed).
    mutating func superEncoder() -> Encoder {
        _JVESuperEncoder(box: box, key: "super", codingPath: codingPath, userInfo: userInfo)
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        _JVESuperEncoder(box: box, key: key.stringValue, codingPath: codingPath + [key], userInfo: userInfo)
    }
}

// MARK: - Super encoder (commits result back to a parent keyed box)

/// An encoder whose `result` is written back into `box[key]` when encoding finishes.
/// Because Swift's `Encoder` protocol has no explicit "finalize" step, we rely on
/// `deinit` to commit the result — this is safe for synchronous (non-escaping) encoding.
private final class _JVESuperEncoder: Encoder {
    let box: _JVEKeyedBox
    let key: String
    let codingPath: [CodingKey]
    let userInfo: [CodingUserInfoKey: Any]
    var result: _JVEBox?

    init(box: _JVEKeyedBox, key: String, codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any]) {
        self.box       = box
        self.key       = key
        self.codingPath = codingPath
        self.userInfo  = userInfo
    }

    deinit { box.dict[key] = result ?? .null }

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        let childBox = _JVEKeyedBox()
        result = .keyed(childBox)
        return KeyedEncodingContainer(
            _JVEKeyedContainer<Key>(box: childBox, codingPath: codingPath, userInfo: userInfo)
        )
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        let childBox = _JVEUnkeyedBox()
        result = .unkeyed(childBox)
        return _JVEUnkeyedContainer(box: childBox, codingPath: codingPath, userInfo: userInfo)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        _JVESingleValueContainer(impl: _JVEImpl(codingPath: codingPath, userInfo: userInfo), codingPath: codingPath)
    }
}

// MARK: - Unkeyed container

private struct _JVEUnkeyedContainer: UnkeyedEncodingContainer {
    let box: _JVEUnkeyedBox
    var codingPath: [CodingKey]
    let userInfo: [CodingUserInfoKey: Any]
    var count: Int { box.array.count }

    private var currentPath: [CodingKey] { codingPath + [_JVEIndexKey(count)] }

    // MARK: Primitive writes
    mutating func encodeNil() throws { box.array.append(.null) }
    mutating func encode(_ v: Bool)   throws { box.array.append(.bool(v)) }
    mutating func encode(_ v: String) throws { box.array.append(.string(v)) }
    mutating func encode(_ v: Double) throws { box.array.append(.number(v)) }
    mutating func encode(_ v: Float)  throws { box.array.append(.number(Double(v))) }
    mutating func encode(_ v: Int)    throws { box.array.append(.number(Double(v))) }
    mutating func encode(_ v: Int8)   throws { box.array.append(.number(Double(v))) }
    mutating func encode(_ v: Int16)  throws { box.array.append(.number(Double(v))) }
    mutating func encode(_ v: Int32)  throws { box.array.append(.number(Double(v))) }
    mutating func encode(_ v: Int64)  throws { box.array.append(.number(Double(v))) }
    mutating func encode(_ v: UInt)   throws { box.array.append(.number(Double(v))) }
    mutating func encode(_ v: UInt8)  throws { box.array.append(.number(Double(v))) }
    mutating func encode(_ v: UInt16) throws { box.array.append(.number(Double(v))) }
    mutating func encode(_ v: UInt32) throws { box.array.append(.number(Double(v))) }
    mutating func encode(_ v: UInt64) throws { box.array.append(.number(Double(v))) }

    // MARK: Generic Encodable write
    mutating func encode<T: Encodable>(_ value: T) throws {
        if let json = value as? JSON {
            box.array.append(_boxFromJSON(json))
            return
        }
        let child = _JVEImpl(codingPath: currentPath, userInfo: userInfo)
        try value.encode(to: child)
        box.array.append(child.result ?? .null)
    }

    // MARK: Nested containers
    mutating func nestedContainer<NK: CodingKey>(keyedBy keyType: NK.Type) -> KeyedEncodingContainer<NK> {
        let childBox = _JVEKeyedBox()
        box.array.append(.keyed(childBox))
        return KeyedEncodingContainer(
            _JVEKeyedContainer<NK>(box: childBox,
                                   codingPath: currentPath,
                                   userInfo: userInfo)
        )
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let childBox = _JVEUnkeyedBox()
        box.array.append(.unkeyed(childBox))
        return _JVEUnkeyedContainer(box: childBox, codingPath: currentPath, userInfo: userInfo)
    }

    mutating func superEncoder() -> Encoder {
        _JVEImpl(codingPath: codingPath, userInfo: userInfo)
    }
}

// MARK: - Single-value container

private struct _JVESingleValueContainer: SingleValueEncodingContainer {
    let impl: _JVEImpl
    var codingPath: [CodingKey]

    mutating func encodeNil() throws { impl.result = .null }
    mutating func encode(_ v: Bool)   throws { impl.result = .bool(v) }
    mutating func encode(_ v: String) throws { impl.result = .string(v) }
    mutating func encode(_ v: Double) throws { impl.result = .number(v) }
    mutating func encode(_ v: Float)  throws { impl.result = .number(Double(v)) }
    mutating func encode(_ v: Int)    throws { impl.result = .number(Double(v)) }
    mutating func encode(_ v: Int8)   throws { impl.result = .number(Double(v)) }
    mutating func encode(_ v: Int16)  throws { impl.result = .number(Double(v)) }
    mutating func encode(_ v: Int32)  throws { impl.result = .number(Double(v)) }
    mutating func encode(_ v: Int64)  throws { impl.result = .number(Double(v)) }
    mutating func encode(_ v: UInt)   throws { impl.result = .number(Double(v)) }
    mutating func encode(_ v: UInt8)  throws { impl.result = .number(Double(v)) }
    mutating func encode(_ v: UInt16) throws { impl.result = .number(Double(v)) }
    mutating func encode(_ v: UInt32) throws { impl.result = .number(Double(v)) }
    mutating func encode(_ v: UInt64) throws { impl.result = .number(Double(v)) }

    mutating func encode<T: Encodable>(_ value: T) throws {
        if let json = value as? JSON {
            impl.result = _boxFromJSON(json)
            return
        }
        // Re-use the same impl so the result is committed to the right place.
        let child = _JVEImpl(codingPath: codingPath, userInfo: impl.userInfo)
        try value.encode(to: child)
        impl.result = child.result
    }
}

// MARK: - Helpers

/// Converts a `JSON` value into a `_JVEBox` without going through `encode(to:)`.
private func _boxFromJSON(_ json: JSON) -> _JVEBox {
    switch json {
    case .null:           return .null
    case .bool(let b):    return .bool(b)
    case .number(let n):  return .number(n)
    case .string(let s):  return .string(s)
    case .object(let d):
        let box = _JVEKeyedBox()
        box.dict = d.mapValues { _boxFromJSON($0) }
        return .keyed(box)
    case .array(let a):
        let box = _JVEUnkeyedBox()
        box.array = a.map { _boxFromJSON($0) }
        return .unkeyed(box)
    }
}

/// Integer-index `CodingKey` for unkeyed containers.
private struct _JVEIndexKey: CodingKey {
    var intValue: Int?
    var stringValue: String { intValue.map(String.init) ?? "" }
    init(_ int: Int)        { intValue = int }
    init?(intValue: Int)    { self.intValue = intValue }
    init?(stringValue: String) {
        guard let i = Int(stringValue) else { return nil }
        intValue = i
    }
}
