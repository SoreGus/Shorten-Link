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

    @Test("Stream: partial → platformImage and title from og:title")
    func testStreamEmitsPlatformImageAndOGTitle() async throws {
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

            if url.host == "example.com" {
                let html = #"""
                <html><head>
                  <meta property="og:title" content="Example OG Title">
                </head><body>...</body></html>
                """#
                let headers = ["Content-Type":"text/html; charset=utf-8"]
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers)!
                return (resp, Data(html.utf8))
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

            let emissions = try await collectFirst(2, from: sut.loadAllDisplayLinksStream())
            try #require(emissions.count == 2)

            switch emissions[0].icon {
            case .none: #expect(true)
            default: Issue.record("First emission should have icon == nil")
            }

            switch emissions[1].icon {
            case .platformImage: #expect(true)
            default: Issue.record("Second emission should have platformImage")
            }
            #expect(emissions[1].title == "Example OG Title")
        }
    }

    @Test("Stream: favicon failed → placeholderSystemName and title from <title>")
    func testStreamEmitsPlaceholderAndHTMLTitleWhenFaviconFails() async throws {
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

            if url.host == "noicon.example" {
                let html = #"""
                <html><head><title>NoIcon Page</title></head><body>...</body></html>
                """#
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type":"text/html; charset=utf-8"])!
                return (resp, Data(html.utf8))
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

            let emissions = try await collectFirst(2, from: sut.loadAllDisplayLinksStream())
            try #require(emissions.count == 2)

            switch emissions[0].icon {
            case .none: #expect(true)
            default: Issue.record("First emission should have icon == nil")
            }

            switch emissions[1].icon {
            case .placeholderSystemName(let name):
                #expect(name == "globe")
            default:
                Issue.record("Second emission should have placeholderSystemName('globe')")
            }
            #expect(emissions[1].title == "NoIcon Page")
        }
    }

    @Test("Stream: title fetch failed → fallback to URL string")
    func testStreamFallsBackToURLStringWhenTitleFetchFails() async throws {
        let (sut, _, mockID) = try makeSUT()

        try await withMock(id: mockID, { request in
            guard let url = request.url else { fatalError("No URL") }

            if request.httpMethod == "GET",
               url.absoluteString.contains("/api/alias/TITLE500") {
                let payload = Data(#"""
                {"url":"https://failtitle.example"}
                """#.utf8)
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (resp, payload)
            }

            if url.host == "failtitle.example" {
                let resp = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
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
            try await sut.save(link: Link(serverID: "TITLE500"))
            await Task.yield()

            let emissions = try await collectFirst(2, from: sut.loadAllDisplayLinksStream())
            try #require(emissions.count == 2)

            switch emissions[1].icon {
            case .platformImage: #expect(true)
            default: Issue.record("Should have loaded platformImage")
            }

            #expect(emissions[1].title == "https://failtitle.example")
        }
    }

    @Test("Stream: invalid favicon MIME → placeholder")
    func testStreamIgnoresFaviconWithInvalidMIME() async throws {
        let (sut, _, mockID) = try makeSUT()

        try await withMock(id: mockID, { request in
            guard let url = request.url else { fatalError("No URL") }

            if request.httpMethod == "GET",
               url.absoluteString.contains("/api/alias/MIMEBAD") {
                let payload = Data(#"""
                {"url":"https://mimebad.example"}
                """#.utf8)
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (resp, payload)
            }

            if url.host == "mimebad.example" {
                let html = #"<html><head><title>MIME Bad</title></head><body/></html>"#
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type":"text/html; charset=utf-8"])!
                return (resp, Data(html.utf8))
            }

            if url.host == "t0.gstatic.com",
               url.path.contains("faviconV2") {
                let headers = ["Content-Type":"application/json"]
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers)!
                return (resp, Data(#"{"not":"image"}"#.utf8))
            }

            let resp = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }) {
            try await sut.save(link: Link(serverID: "MIMEBAD"))
            await Task.yield()

            let emissions = try await collectFirst(2, from: sut.loadAllDisplayLinksStream())
            try #require(emissions.count == 2)

            switch emissions[1].icon {
            case .placeholderSystemName(let name):
                #expect(name == "globe")
            default:
                Issue.record("Should use placeholderSystemName('globe') when MIME is not image/*")
            }
            #expect(emissions[1].title == "MIME Bad")
        }
    }

    @Test("Stream: finishes without emitting when server resolution fails")
    func testStreamFinishesWhenServerResolutionFails() async throws {
        let (sut, _, mockID) = try makeSUT()

        try await withMock(id: mockID, { request in
            guard let url = request.url else { fatalError("No URL") }

            if request.httpMethod == "GET",
               url.absoluteString.contains("/api/alias/FAIL001") {
                let resp = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
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
@MainActor
extension LinkDisplayTests {
    private func countStoredLinks(_ context: ModelContext) throws -> Int {
        try context.fetch(FetchDescriptor<StoredLink>()).count
    }
    
    @MainActor
    private func waitUntil(
        _ condition: @escaping () throws -> Bool,
        timeout seconds: TimeInterval = 2.0,
        poll interval: TimeInterval = 0.05
    ) async throws {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if (try? condition()) == true { return }
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
        _ = try? condition()
    }
}

@MainActor
extension LinkDisplayTests {
    @Test("Stream: 404 notFound → deletes locally and emits no items")
    func testStreamDeletesLocalRecordOnNotFoundAndEmitsNothing() async throws {
        let (sut, context, mockID) = try makeSUT()

        try await withMock(id: mockID, { request in
            guard let url = request.url else { fatalError("No URL") }

            if request.httpMethod == "GET",
               url.absoluteString.contains("/api/alias/DEAD404") {
                let resp = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }

            let resp = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }) {
            try await sut.save(link: Link(serverID: "DEAD404"))
            #expect(try countStoredLinks(context) == 1)

            var received: [DisplayLink] = []
            do {
                for try await item in sut.loadAllDisplayLinksStream() {
                    received.append(item)
                }
            } catch {
                Issue.record("Stream should not throw: \(error)")
            }
            #expect(received.isEmpty, "No emissions were expected for DEAD404")

            try await waitUntil({
                try self.countStoredLinks(context) == 0
            }, timeout: 2.0, poll: 0.05)

            #expect(
                try countStoredLinks(context) == 0,
                "The StoredLink with serverID=DEAD404 should have been deleted"
            )
        }
    }
}
