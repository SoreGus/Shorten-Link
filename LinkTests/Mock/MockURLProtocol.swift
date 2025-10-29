//
//  MockURLProtocol.swift
//  Link
//
//  Created by Gustavo Soré on 29/10/25.
//

import Foundation

final class MockURLProtocol: URLProtocol {
    private static let lock = DispatchQueue(label: "MockURLProtocol.lock")
    private static var _requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

    static func set(_ handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data?)) {
        lock.sync { _requestHandler = handler }
    }

    static func clear() {
        lock.sync { _requestHandler = nil }
    }

    private static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data?))? {
        lock.sync { _requestHandler }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
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
