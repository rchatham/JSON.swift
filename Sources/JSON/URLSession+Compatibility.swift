//
//  URLSession+Compatibility.swift
//  JSON
//

#if os(Linux) && compiler(<6.0)
import Foundation
import FoundationNetworking

extension URLSession {

    /// Async wrapper around the callback-based `dataTask(with:completionHandler:)`,
    /// bridging the gap on Linux Swift 5.x where `data(for:)` is not available.
    ///
    /// - Parameter request: The `URLRequest` to execute.
    /// - Returns: A tuple of the response `Data` and the `URLResponse`.
    /// - Throws: `CancellationError` if the task was cancelled before starting;
    ///   the `dataTask` completion error or `URLError(.badServerResponse)` otherwise.
    func jsonData(for request: URLRequest) async throws -> (Data, URLResponse) {
        try Task.checkCancellation()
        let holder = TaskHolder()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = self.dataTask(with: request) { data, response, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let data = data, let response = response {
                        continuation.resume(returning: (data, response))
                    } else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                    }
                }
                holder.install(task: task)
            }
        } onCancel: {
            holder.cancel()
        }
    }
}

// MARK: - Cancellation helper

/// Holds a reference to the in-flight `URLSessionDataTask` so it can be
/// cancelled when the Swift concurrency task is cancelled.
///
/// Marked `@unchecked Sendable` because all access to `task` and `cancelled`
/// is serialised behind `lock`; the class never escapes the scope of a single
/// `jsonData(for:)` call.
private final class TaskHolder: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionDataTask?
    private var cancelled = false

    deinit { task?.cancel() }

    /// Installs the data task, handling a race where cancellation arrived
    /// between task creation and storage. Always resumes the task so the
    /// completion handler fires — even if cancelled — guaranteeing the
    /// continuation is resumed exactly once.
    func install(task t: URLSessionDataTask) {
        lock.lock()
        let wasCancelled = cancelled
        if !wasCancelled { task = t }
        lock.unlock()
        if wasCancelled { t.cancel() }
        t.resume()
    }

    /// Cancels the stored task (if any) under the lock, then clears the
    /// reference so `deinit` won't double-cancel.
    func cancel() {
        lock.lock()
        cancelled = true
        let t = task
        task = nil
        lock.unlock()
        t?.cancel()
    }
}
#endif