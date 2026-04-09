//
//  JSONDiff.swift
//  JSON
//
//  Created by Reid Chatham on 4/7/25.
//
//  Structural diff between two JSON values.
//
//  Path convention
//  ---------------
//  Paths use a custom dot/bracket notation (not RFC 6901 JSON Pointer):
//    • Object keys  → "root.key"  (e.g. "root.user.name")
//    • Array indices → "root[i]"  (e.g. "root.items[2]")
//
//  This notation is intentionally different from the JSON Pointer subscript
//  (`json[pointer: "/user/name"]`) which uses slash-separated RFC 6901 tokens.
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
///
/// ## Path format
/// Paths use dot-separated keys for objects and bracket notation for array
/// indices: `"root.user.address.city"`, `"root.items[0]"`.
/// This differs from the RFC 6901 JSON Pointer syntax used by `json[pointer:]`.
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

// MARK: - Recursive diff engine

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
            switch (oldDict[key], newDict[key]) {
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
        lcsArrayDiff(from: oldArr, into: newArr, path: path, changes: &changes)

    default:
        // Different types or primitives that differ.
        changes.append(.modified(path: path, from: old, to: new))
    }
}

// MARK: - LCS-based array diff

/// Diffs two JSON arrays using the Longest Common Subsequence algorithm.
///
/// - Elements present in the LCS (identical in both arrays at matched positions) are skipped.
/// - Unmatched old/new elements are paired in order: the first pair becomes a recursive
///   `jsonDiffCollect` call (generating `modified` if they differ), additional unmatched
///   old elements are `removed`, additional unmatched new elements are `added`.
///
/// This correctly identifies prepend/insert/delete operations instead of reporting
/// every downstream element as `modified` (the naive index-based approach).
private func lcsArrayDiff(
    from oldArr: [JSON],
    into newArr: [JSON],
    path: String,
    changes: inout [JSONDiff.Change]
) {
    let matches = lcs(oldArr, newArr)
    let matchedOldIdx = Set(matches.map(\.0))
    let matchedNewIdx = Set(matches.map(\.1))

    // Collect unmatched elements in their original order.
    let orphanOld = oldArr.enumerated().filter { !matchedOldIdx.contains($0.offset) }
    let orphanNew = newArr.enumerated().filter { !matchedNewIdx.contains($0.offset) }

    // Pair orphans positionally: same-slot pairs are recursively diffed (captures
    // in-place modifications like `[1, 2, 3] → [1, 99, 3]`).
    let pairCount = min(orphanOld.count, orphanNew.count)

    for i in 0..<pairCount {
        let (oldIdx, oldVal) = orphanOld[i]
        let (_, newVal)       = orphanNew[i]
        jsonDiffCollect(from: oldVal, into: newVal,
                        path: "\(path)[\(oldIdx)]", changes: &changes)
    }

    // Remaining unmatched old elements → removed.
    for i in pairCount..<orphanOld.count {
        let (oldIdx, oldVal) = orphanOld[i]
        changes.append(.removed(path: "\(path)[\(oldIdx)]", value: oldVal))
    }

    // Remaining unmatched new elements → added.
    for i in pairCount..<orphanNew.count {
        let (newIdx, newVal) = orphanNew[i]
        changes.append(.added(path: "\(path)[\(newIdx)]", value: newVal))
    }
}

// MARK: - LCS (Longest Common Subsequence)

/// Returns matched index pairs `(oldIdx, newIdx)` from the LCS of two JSON arrays.
/// Elements are compared with `==` (strict equality).
private func lcs(_ a: [JSON], _ b: [JSON]) -> [(Int, Int)] {
    let m = a.count, n = b.count
    guard m > 0, n > 0 else { return [] }

    // DP table — O(m × n) time and space.
    var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
    for i in 1...m {
        for j in 1...n {
            dp[i][j] = (a[i-1] == b[j-1])
                ? dp[i-1][j-1] + 1
                : max(dp[i-1][j], dp[i][j-1])
        }
    }

    // Backtrack to collect matched index pairs.
    var matches: [(Int, Int)] = []
    var i = m, j = n
    while i > 0, j > 0 {
        if a[i-1] == b[j-1] {
            matches.append((i-1, j-1))
            i -= 1; j -= 1
        } else if dp[i-1][j] > dp[i][j-1] {
            i -= 1
        } else {
            j -= 1
        }
    }
    return matches.reversed()
}
