//
//  LinkDisplayTests.swift
//  Link
//

import Testing
import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif
@testable import Link

@MainActor
@Suite("Link Display Stream")
struct LinkDisplayTests {

    private func makeSUT() throws -> (sut: LinkService, context: ModelContext, mockID: String) {
        let mockID = UUID().uuidString

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Mock-ID": mockID]
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration)

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: StoredLink.self, configurations: config)
        let context = ModelContext(container)
        let sut = LinkService(context: context, session: session)
        return (sut, context, mockID)
    }

    private func withMock(
        id: String,
        _ handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data?),
        perform body: @escaping () async throws -> Void
    ) async rethrows {
        MockURLProtocol.set(id, handler)
        defer { MockURLProtocol.clear(id) }
        try await body()
        await Task.yield()
    }

    private var onePixelPNG: Data {
        Data([
            0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A,
            0x00,0x00,0x00,0x0D,0x49,0x48,0x44,0x52,
            0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x01,
            0x08,0x06,0x00,0x00,0x00,0x1F,0x15,0xC4,
            0x89,0x00,0x00,0x00,0x0A,0x49,0x44,0x41,
            0x54,0x78,0x9C,0x63,0xF8,0xCF,0xC0,0x00,
            0x00,0x03,0x01,0x01,0x00,0x18,0xDD,0x8D,
            0x18,0x00,0x00,0x00,0x00,0x49,0x45,0x4E,
            0x44,0xAE,0x42,0x60,0x82
        ])
    }

    private func collectFirst(
        _ desired: Int,
        from stream: AsyncThrowingStream<DisplayLink, Error>,
        timeout seconds: TimeInterval = 5.0
    ) async throws -> [DisplayLink] {
        var results: [DisplayLink] = []
        let deadline = Date().addingTimeInterval(seconds)
        var iterator = stream.makeAsyncIterator()
        while results.count < desired, Date() < deadline {
            if let next = try await iterator.next() {
                results.append(next)
            } else {
                break
            }
        }
        return results
    }

    @Test("Stream yields partial then platformImage when favicon succeeds")
    func testStreamEmitsPartialThenPlatformImage() async throws {
        let (sut, _, mockID) = try makeSUT()

        try await withMock(id: mockID, { request in
            guard let url = request.url else { fatalError("No URL") }

            if request.httpMethod == "GET",
               url.absoluteString.contains("/api/alias/A1B2C3") {
                let payload = Data(#"""
                {"url":"https://example.com"}
                """#.utf8)
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (resp, payload)
            }

            if url.host == "t0.gstatic.com",
               url.path.contains("faviconV2") {
                let headers = ["Content-Type":"image/png"]
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers)!
                return (resp, onePixelPNG)
            }

            let resp = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }) {
            try await sut.save(link: Link(serverID: "A1B2C3"))
            await Task.yield()
            let stored = try await sut.loadAll()
            try #require(stored.count == 1)
            let emissions = try await collectFirst(2, from: sut.loadAllDisplayLinksStream(), timeout: 5.0)
            try #require(emissions.count == 2)

            switch emissions[0].icon {
            case .none: #expect(true)
            default: Issue.record("First emission should have icon == nil")
            }

            switch emissions[1].icon {
            case .platformImage: #expect(true)
            default: Issue.record("Second emission should have platformImage")
            }
        }
    }

    @Test("Stream yields only partial when favicon fails")
    func testStreamEmitsOnlyPartialWhenFaviconFails() async throws {
        let (sut, _, mockID) = try makeSUT()

        try await withMock(id: mockID, { request in
            guard let url = request.url else { fatalError("No URL") }

            if request.httpMethod == "GET",
               url.absoluteString.contains("/api/alias/ZZZ999") {
                let payload = Data(#"""
                {"url":"https://noicon.example"}
                """#.utf8)
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (resp, payload)
            }

            if url.host == "t0.gstatic.com",
               url.path.contains("faviconV2") {
                let headers = ["Content-Type":"text/plain"]
                let resp = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: headers)!
                return (resp, Data("not found".utf8))
            }

            let resp = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }) {
            try await sut.save(link: Link(serverID: "ZZZ999"))
            await Task.yield()
            let stored = try await sut.loadAll()
            try #require(stored.count == 1)
            let emissions = try await collectFirst(2, from: sut.loadAllDisplayLinksStream(), timeout: 5.0)
            try #require(emissions.count >= 1)

            switch emissions[0].icon {
            case .none: #expect(true)
            default: Issue.record("First emission should have icon == nil")
            }

            if emissions.count > 1 {
                switch emissions[1].icon {
                case .platformImage:
                    Issue.record("Should not have platformImage when favicon fails")
                default:
                    #expect(true)
                }
            }
        }
    }

    @Test("Stream finishes when server resolution fails")
    func testStreamFinishesWhenServerResolutionFails() async throws {
        let (sut, _, mockID) = try makeSUT()

        try await withMock(id: mockID, { request in
            guard let url = request.url else { fatalError("No URL") }

            if request.httpMethod == "GET",
               url.absoluteString.contains("/api/alias/FAIL001") {
                let resp = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }

            if url.host == "t0.gstatic.com",
               url.path.contains("faviconV2") {
                let resp = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }

            let resp = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }) {
            try await sut.save(link: Link(serverID: "FAIL001"))
            var received: [DisplayLink] = []
            do {
                for try await item in sut.loadAllDisplayLinksStream() {
                    received.append(item)
                }
                #expect(true)
            } catch {
                Issue.record("Stream should not throw: \(error)")
            }
            #expect(received.isEmpty)
        }
    }
}
