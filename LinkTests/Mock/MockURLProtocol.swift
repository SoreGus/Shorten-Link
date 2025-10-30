//
//  MockURLProtocol.swift
//  Link
//

import Foundation

final class MockURLProtocol: URLProtocol {

    // MARK: - Routing por mockID

    private static let headerKey = "X-Mock-ID"

    private static var lock = NSLock()
    private static var handlers: [String: (URLRequest) throws -> (HTTPURLResponse, Data?)] = [:]

    static func set(_ id: String, _ handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data?)) {
        lock.lock(); defer { lock.unlock() }
        handlers[id] = handler
    }

    static func clear(_ id: String) {
        lock.lock(); defer { lock.unlock() }
        handlers[id] = nil
    }

    private static func handler(for id: String) -> ((URLRequest) throws -> (HTTPURLResponse, Data?))? {
        lock.lock(); defer { lock.unlock() }
        return handlers[id]
    }

    // MARK: - URLProtocol overrides

    override class func canInit(with request: URLRequest) -> Bool {
        request.value(forHTTPHeaderField: headerKey) != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let id = request.value(forHTTPHeaderField: Self.headerKey),
              let handler = Self.handler(for: id)
        else {
            let url = request.url ?? URL(string: "about:blank")!
            let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data())
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data { client?.urlProtocol(self, didLoad: data) }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
