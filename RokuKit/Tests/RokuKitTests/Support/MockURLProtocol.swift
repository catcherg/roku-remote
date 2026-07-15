import Foundation
import XCTest

/// URLProtocol mock injected via `ECPClient.makeSession(protocolClasses:)`.
/// Records every request and answers from a configurable handler.
final class MockURLProtocol: URLProtocol {
    /// Answers each request. Set in test setUp; cleared in tearDown.
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (statusCode: Int, data: Data))?
    nonisolated(unsafe) private static var _recorded: [URLRequest] = []
    private static let lock = NSLock()

    static var recordedRequests: [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return _recorded
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        _recorded = []
        handler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self._recorded.append(request)
        Self.lock.unlock()

        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (statusCode, data) = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

extension MockURLProtocol {
    /// Convenience: always succeed with 200 + given data.
    static func succeed(with data: Data = Data()) {
        handler = { _ in (200, data) }
    }

    /// Convenience: always fail with the given HTTP status.
    static func fail(statusCode: Int) {
        handler = { _ in (statusCode, Data()) }
    }
}
