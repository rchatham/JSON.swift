//
//  JSONDiff.swift
//  JSON
//
//  Created by Reid Chatham on 4/7/25.
//
//  Structural diff between two JSON values.
//

import Foundation

// MARK: - JSONDiff

/// Describes the structural difference between two `JSON` values.
///
/// ```swift
/// let old: JSON = ["name": "Alice", "age": 30]
/// let new: JSON = ["name": "Alice", "age": 31, "active": true]
/// let diff = new.diff(from: old)
/// // diff.changes contains:
/// //   .modified(path: "root.age",    from: .number(30),  to: .number(31))
/// //   .added(path: "root.active",    value: .bool(true))
/// ```
public struct JSONDiff: Sendable {

    // MARK: - Change

    /// A single change in a JSON diff.
    public enum Change: Sendable, Equatable {
        /// A key/index was present in `from` but absent in `to`.
        case removed(path: String, value: JSON)

        /// A key/index is absent in `from` but present in `to`.
        case added(path: String, value: JSON)

        /// A key/index exists in both but the values differ.
        case modified(path: String, from: JSON, to: JSON)

        /// The JSON path where this change occurred.
        public var path: String {
            switch self {
            case .removed(let p, _):      return p
            case .added(let p, _):        return p
            case .modified(let p, _, _):  return p
            }
        }
    }

    /// All changes from `from` to `to`.
    public let changes: [Change]

    /// `true` when the two values are identical (no changes).
    public var isEmpty: Bool { changes.isEmpty }

    /// Only additions.
    public var additions: [Change] {
        changes.filter { if case .added   = $0 { return true }; return false }
    }
    /// Only removals.
    public var removals: [Change] {
        changes.filter { if case .removed = $0 { return true }; return false }
    }
    /// Only modifications.
    public var modifications: [Change] {
        changes.filter { if case .modified = $0 { return true }; return false }
    }
}

// MARK: - JSON.diff(from:)

extension JSON {
    /// Returns the structural diff between `self` (the new value) and `other` (the old value).
    ///
    /// - Parameter other: The baseline value to diff against.
    /// - Returns: A `JSONDiff` describing all additions, removals, and modifications.
    public func diff(from other: JSON) -> JSONDiff {
        var changes: [JSONDiff.Change] = []
        jsonDiffCollect(from: other, into: self, path: "root", changes: &changes)
        return JSONDiff(changes: changes)
    }
}

// MARK: - Recursive diff engine (free function to avoid name conflicts)

private func jsonDiffCollect(
    from old: JSON,
    into new: JSON,
    path: String,
    changes: inout [JSONDiff.Change]
) {
    if old == new { return }

    switch (old, new) {
    case (.object(let oldDict), .object(let newDict)):
        let allKeys = Set(oldDict.keys).union(newDict.keys).sorted()
        for key in allKeys {
            let childPath = "\(path).\(key)"
            let oldVal = oldDict[key]
            let newVal = newDict[key]
            switch (oldVal, newVal) {
            case (nil, let v?):
                changes.append(.added(path: childPath, value: v))
            case (let v?, nil):
                changes.append(.removed(path: childPath, value: v))
            case (let o?, let n?):
                jsonDiffCollect(from: o, into: n, path: childPath, changes: &changes)
            case (nil, nil):
                break
            }
        }

    case (.array(let oldArr), .array(let newArr)):
        let count = Swift.max(oldArr.count, newArr.count)
        for i in 0..<count {
            let childPath = "\(path)[\(i)]"
            let oldVal: JSON? = i < oldArr.count ? oldArr[i] : nil
            let newVal: JSON? = i < newArr.count ? newArr[i] : nil
            switch (oldVal, newVal) {
            case (nil, let v?):
                changes.append(.added(path: childPath, value: v))
            case (let v?, nil):
                changes.append(.removed(path: childPath, value: v))
            case (let o?, let n?):
                jsonDiffCollect(from: o, into: n, path: childPath, changes: &changes)
            case (nil, nil):
                break
            }
        }

    default:
        // Different types or primitives that differ.
        changes.append(.modified(path: path, from: old, to: new))
    }
}
