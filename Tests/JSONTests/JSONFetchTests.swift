//
//  JSONFetchTests.swift
//  JSONTests
//

import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import JSON

// MARK: - Mock URLProtocol (zero static state, fixed routes)

private final class MockJSONURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        switch url.path {
        case "/success": respond(200, #"{"name":"Alice","age":30}"#)
        case "/post":    respondEcho()
        case "/missing": respond(404, #"{"error":"not_found"}"#)
        case "/invalid": respond(200, "plain text, not json")
        default: client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
        }
    }

    private func respond(_ status: Int, _ body: String) {
        guard let resp = HTTPURLResponse(url: request.url!, statusCode: status,
                httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    private func respondEcho() {
        let bodyData = Self.readBody(from: request)
        let jsonBody: Any
        if let obj = try? JSONSerialization.jsonObject(with: bodyData) {
            jsonBody = obj
        } else {
            jsonBody = String(data: bodyData, encoding: .utf8) ?? bodyData.base64EncodedString()
        }
        let echo: [String: Any] = [
            "method": request.httpMethod ?? "",
            "body": jsonBody,
            "headers": request.allHTTPHeaderFields ?? [:],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: echo),
              let resp = HTTPURLResponse(url: request.url!, statusCode: 201,
                  httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    private static func readBody(from request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open(); defer { stream.close() }
        var data = Data()
        var buf = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let n = stream.read(&buf, maxLength: buf.count)
            guard n > 0 else { break }
            data.append(buf, count: n)
        }
        return data
    }
}

// MARK: - Tests

final class JSONFetchTests: XCTestCase {

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockJSONURLProtocol.self]
        return URLSession(configuration: config)
    }

    func test_fetch_get_success() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let json = try await JSON.fetch(from: URL(string: "https://test/success")!, session: session)
        XCTAssertEqual(json["name"], "Alice")
        XCTAssertEqual(json["age"], .number(30))
    }

    func test_fetch_post_echo() async throws {
        var req = URLRequest(url: URL(string: "https://test/post")!)
        req.httpMethod = "POST"
        req.httpBody = Data(#"{"key":"value"}"#.utf8)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer t", forHTTPHeaderField: "Authorization")
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let json = try await JSON.fetch(request: req, session: session)
        XCTAssertEqual(json["method"], "POST")
        XCTAssertEqual(json["body"]?["key"], "value")
        XCTAssertEqual(json["headers"]?["Content-Type"], "application/json")
        XCTAssertEqual(json["headers"]?["Authorization"], "Bearer t")
    }

    func test_fetch_404_http_error() async {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        do {
            _ = try await JSON.fetch(from: URL(string: "https://test/missing")!, session: session)
            XCTFail("Expected httpError")
        } catch let error as JSONError {
            guard case .httpError(404, let body) = error else {
                return XCTFail("Expected .httpError(404, _), got \(error)")
            }
            XCTAssertEqual(body?["error"], "not_found")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_fetch_200_invalid_json_body_throws_decoding_error() async {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        do {
            _ = try await JSON.fetch(from: URL(string: "https://test/invalid")!, session: session)
            XCTFail("Expected DecodingError")
        } catch is DecodingError {
            // Expected: invalid JSON body
        } catch {
            XCTFail("Expected DecodingError, got \(type(of: error)): \(error)")
        }
    }

    func test_fetch_unmapped_route_propagates_url_error_code() async {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        do {
            _ = try await JSON.fetch(from: URL(string: "https://test/unknown")!, session: session)
            XCTFail("Expected URLError")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .badServerResponse)
        } catch {
            XCTFail("Expected URLError, got \(type(of: error)): \(error)")
        }
    }
}