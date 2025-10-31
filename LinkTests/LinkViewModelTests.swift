//
//  LinkViewModelTests.swift
//  LinkTests
//

import Testing
import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#endif
@testable import Link

private let onePixelPNG: Data = Data([
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

private func makeDisplayLink(
    serverID: String,
    url: String,
    title: String = "",
    icon: DisplayIcon? = nil
) -> DisplayLink {
    let link = Link(serverID: serverID)
    return DisplayLink(link: link, title: title, url: url, icon: icon)
}

@MainActor
@Suite("LinkViewModel (with concrete LinkService)")
struct LinkViewModelTests {

    private func makeService(mockID: String) throws -> LinkService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Mock-ID": mockID]
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration)

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: StoredLink.self, configurations: config)
        let context = ModelContext(container)

        return LinkService(context: context, session: session)
    }

    private func makeSUT() throws -> (vm: LinkViewModel, service: LinkService, mockID: String) {
        let mockID = UUID().uuidString
        let service = try makeService(mockID: mockID)
        let vm = LinkViewModel(service: service)
        return (vm, service, mockID)
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

    @Test("loadAll: partial → full (platformImage) with og:title")
    func testLoadAll_PartialThenFullWithOGTitle() async throws {
        let (vm, service, mockID) = try makeSUT()

        try await withMock(id: mockID, { request in
            guard let url = request.url else { fatalError("No URL") }

            if request.httpMethod == "GET",
               url.absoluteString.contains("/api/alias/S1") {
                let payload = Data(#"{ "url":"https://example.com" }"#.utf8)
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

            if url.host == "t0.gstatic.com", url.path.contains("faviconV2") {
                let headers = ["Content-Type":"image/png"]
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers)!
                return (resp, onePixelPNG)
            }

            let resp = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }) {
            try await service.save(link: Link(serverID: "S1"))

            vm.loadAll()
            try await Task.sleep(nanoseconds: 800_000_000)

            try #require(vm.displayLinks.count == 1)
            let item = vm.displayLinks[0]
            #expect(item.link.serverID == "S1")
            #expect(item.title == "Example OG Title")
            switch item.icon {
            case .platformImage: #expect(true)
            default: Issue.record("Expected platformImage on the final item")
            }
            #expect(vm.errorMessage == nil)
        }
    }

    @Test("loadAll: invalid favicon MIME → placeholderSystemName('globe') with <title>")
    func testLoadAll_FaviconInvalid_UsesPlaceholderAndHTMLTitle() async throws {
        let (vm, service, mockID) = try makeSUT()

        try await withMock(id: mockID, { request in
            guard let url = request.url else { fatalError("No URL") }

            if request.httpMethod == "GET",
               url.absoluteString.contains("/api/alias/ZZZ999") {
                let payload = Data(#"{ "url":"https://noicon.example" }"#.utf8)
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (resp, payload)
            }

            if url.host == "noicon.example" {
                let html = #"<html><head><title>NoIcon Page</title></head><body/></html>"#
                let headers = ["Content-Type":"text/html; charset=utf-8"]
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers)!
                return (resp, Data(html.utf8))
            }

            if url.host == "t0.gstatic.com", url.path.contains("faviconV2") {
                let headers = ["Content-Type":"application/json"]
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers)!
                return (resp, Data(#"{"not":"image"}"#.utf8))
            }

            let resp = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }) {
            try await service.save(link: Link(serverID: "ZZZ999"))

            vm.loadAll()
            try await Task.sleep(nanoseconds: 150_000_000)

            try #require(vm.displayLinks.count == 1)
            let item = vm.displayLinks[0]
            #expect(item.title == "NoIcon Page")
            switch item.icon {
            case .placeholderSystemName(let name): #expect(name == "globe")
            default: Issue.record("Expected placeholderSystemName('globe') when MIME != image/*")
            }
        }
    }

    @Test("loadAll: title fetch fails → fallback to URL string")
    func testLoadAll_TitleFetchFails_FallsBackToURLString() async throws {
        let (vm, service, mockID) = try makeSUT()

        try await withMock(id: mockID, { request in
            guard let url = request.url else { fatalError("No URL") }

            if request.httpMethod == "GET",
               url.absoluteString.contains("/api/alias/TITLE500") {
                let payload = Data(#"{ "url":"https://failtitle.example" }"#.utf8)
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (resp, payload)
            }

            if url.host == "failtitle.example" {
                let resp = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }

            if url.host == "t0.gstatic.com", url.path.contains("faviconV2") {
                let headers = ["Content-Type":"image/png"]
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers)!
                return (resp, onePixelPNG)
            }

            let resp = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }) {
            try await service.save(link: Link(serverID: "TITLE500"))

            vm.loadAll()
            try await Task.sleep(nanoseconds: 150_000_000)

            try #require(vm.displayLinks.count == 1)
            let item = vm.displayLinks[0]
            #expect(item.title == "https://failtitle.example")
            switch item.icon {
            case .platformImage: #expect(true)
            default: Issue.record("Expected platformImage when favicon loads")
            }
        }
    }

    @Test("trySearch: invalid URL → errorMessage='Invalid URL' and no side-effects")
    func testTrySearch_InvalidURL() async throws {
        let (vm, _, _) = try makeSUT()
        await vm.trySearch(rawInput: "   ")
        #expect(vm.errorMessage == "Invalid URL")
        #expect(vm.searchResult == nil)
        #expect(vm.lastSearchAttempted == false)
        #expect(vm.isSearching == false)
    }

    @Test("searchByURL: success with favicon → searchResult has platformImage")
    func testSearchByURL_Success_WithFavicon() async throws {
        let (vm, _, mockID) = try makeSUT()

        try await withMock(id: mockID, { request in
            guard let url = request.url else { fatalError("No URL") }

            if request.httpMethod == "POST",
               url.absoluteString.contains("/api/alias") {
                let body = #"{ "alias":"NEWID", "_links": { "self":"https://example.com", "short":"https://sho.rt/NEWID" } }"#
                let resp = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)!
                return (resp, Data(body.utf8))
            }

            if request.httpMethod == "GET",
               url.absoluteString.contains("/api/alias/NEWID") {
                let payload = Data(#"{ "url":"https://example.com" }"#.utf8)
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (resp, payload)
            }

            if url.host == "t0.gstatic.com", url.path.contains("faviconV2") {
                let headers = ["Content-Type":"image/png"]
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers)!
                return (resp, onePixelPNG)
            }

            let resp = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }) {
            await vm.searchByURL("https://example.com")

            #expect(vm.isSearching == false)
            #expect(vm.lastSearchAttempted == true)
            #expect(vm.errorMessage == nil)

            let result = try #require(vm.searchResult)
            #expect(result.link.serverID == "NEWID")
            switch result.icon {
            case .platformImage: #expect(true)
            default: Issue.record("Expected platformImage when favicon loads")
            }
        }
    }

    @Test("searchByURL: success without favicon → keeps icon absent")
    func testSearchByURL_Success_WithoutFavicon() async throws {
        let (vm, _, mockID) = try makeSUT()

        try await withMock(id: mockID, { request in
            guard let url = request.url else { fatalError("No URL") }

            if request.httpMethod == "POST",
               url.absoluteString.contains("/api/alias") {
                let body = #"{ "alias":"ID2", "_links": { "self":"https://noicon.example", "short":"https://sho.rt/ID2" } }"#
                let resp = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)!
                return (resp, Data(body.utf8))
            }

            if request.httpMethod == "GET",
               url.absoluteString.contains("/api/alias/ID2") {
                let payload = Data(#"{ "url":"https://noicon.example" }"#.utf8)
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (resp, payload)
            }

            if url.host == "t0.gstatic.com", url.path.contains("faviconV2") {
                let resp = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: ["Content-Type":"text/plain"])!
                return (resp, Data("not found".utf8))
            }

            let resp = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }) {
            await vm.searchByURL("https://noicon.example")

            let result = try #require(vm.searchResult)
            #expect(result.link.serverID == "ID2")
            switch result.icon {
            case .platformImage:
                Issue.record("Should not be platformImage when favicon is missing")
            default:
                #expect(true)
            }
        }
    }

    @Test("searchByURL: create() fails → errorMessage = 'HTTP error: 400'")
    func testSearchByURL_CreateFails() async throws {
        let (vm, _, mockID) = try makeSUT()

        await withMock(id: mockID, { request in
            guard let url = request.url else { fatalError("No URL") }

            if request.httpMethod == "POST",
               url.absoluteString.contains("/api/alias") {
                let resp = HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: nil)!
                return (resp, Data(#"{ "message":"bad" }"#.utf8))
            }

            let resp = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }) {
            await vm.searchByURL("https://bad.example")
            #expect(vm.searchResult == nil)
            #expect(vm.errorMessage == "HTTP error: 400")
            #expect(vm.lastSearchAttempted == true)
            #expect(vm.isSearching == false)
        }
    }

    @Test("searchByURL: load() fails after create() → errorMessage = 'Not found'")
    func testSearchByURL_LoadFailsAfterCreate() async throws {
        let (vm, _, mockID) = try makeSUT()

        await withMock(id: mockID, { request in
            guard let url = request.url else { fatalError("No URL") }

            if request.httpMethod == "POST",
               url.absoluteString.contains("/api/alias") {
                let body = #"{ "alias":"X404", "_links": { "self":"https://x404.example", "short":"https://sho.rt/X404" } }"#
                let resp = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)!
                return (resp, Data(body.utf8))
            }

            if request.httpMethod == "GET",
               url.absoluteString.contains("/api/alias/X404") {
                let resp = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }

            let resp = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }) {
            await vm.searchByURL("https://x404.example")
            #expect(vm.searchResult == nil)
            #expect(vm.errorMessage == "Not found")
            #expect(vm.lastSearchAttempted == true)
            #expect(vm.isSearching == false)
        }
    }

    @Test("saveCurrentSearchResult: success → inserts/promotes to top and clears search")
    func testSaveCurrentSearchResult_Success() async throws {
        let (vm, service, _) = try makeSUT()

        vm.displayLinks = [
            makeDisplayLink(serverID: "A", url: "https://a.com", title: "A", icon: .placeholderSystemName("globe")),
            makeDisplayLink(serverID: "B", url: "https://b.com", title: "B", icon: .placeholderSystemName("globe"))
        ]

        vm.searchResult = makeDisplayLink(serverID: "NEW", url: "https://new.com", title: "New", icon: .placeholderSystemName("globe"))

        try await service.save(link: vm.searchResult!.link)

        await vm.saveCurrentSearchResult()

        try #require(vm.displayLinks.first?.link.serverID == "NEW")
        #expect(vm.searchResult == nil)
        #expect(vm.lastSearchAttempted == false)
        #expect(vm.isSearching == false)
        #expect(vm.isSavingSearchResult == false)
        #expect(vm.errorMessage == nil)
    }

    @Test("delete(serverID:): success → removes item")
    func testDelete_Success() async throws {
        let (vm, service, _) = try makeSUT()

        try await service.save(link: Link(serverID: "Y"))

        vm.displayLinks = [
            makeDisplayLink(serverID: "X", url: "https://x.com"),
            makeDisplayLink(serverID: "Y", url: "https://y.com"),
            makeDisplayLink(serverID: "Z", url: "https://z.com")
        ]

        await vm.delete(serverID: "Y")
        #expect(vm.displayLinks.map(\.link.serverID) == ["X", "Z"])
        #expect(vm.errorMessage == nil)
    }

    @Test("delete(serverID:): item missing in storage → rollback and 'Local item not found'")
    func testDelete_NotFound_RestoresSnapshot() async throws {
        let (vm, _, _) = try makeSUT()

        vm.displayLinks = [
            makeDisplayLink(serverID: "K", url: "https://k.com"),
            makeDisplayLink(serverID: "M", url: "https://m.com")
        ]

        await vm.delete(serverID: "M")

        #expect(vm.displayLinks.map(\.link.serverID) == ["K", "M"])
        #expect(vm.errorMessage == "Local item not found")
    }

    @Test("delete(at:): removes multiple indices")
    func testDeleteAt_RemovesMultiple() async throws {
        let (vm, service, _) = try makeSUT()

        try await service.save(link: Link(serverID: "B"))
        try await service.save(link: Link(serverID: "C"))

        vm.displayLinks = [
            makeDisplayLink(serverID: "A", url: "https://a.com"),
            makeDisplayLink(serverID: "B", url: "https://b.com"),
            makeDisplayLink(serverID: "C", url: "https://c.com"),
            makeDisplayLink(serverID: "D", url: "https://d.com")
        ]

        vm.delete(at: IndexSet([1, 2]))
        try await Task.sleep(nanoseconds: 80_000_000)

        #expect(vm.displayLinks.map(\.link.serverID) == ["A","D"])
    }
    
    @Test("normalizedURL/isValidURLForSearch: accept http/https and rejects invalid ones")
    func testURLValidation() async throws {
        let (vm, _, _) = try makeSUT()
        #expect(vm.isValidURLForSearch("https://example.com") == true)
        #expect(vm.isValidURLForSearch("http://example.com") == true)
        #expect(vm.isValidURLForSearch("example.com") == true)
        #expect(vm.isValidURLForSearch("   ") == false)
        #expect(vm.isValidURLForSearch("ftp://example.com") == false)
        #expect(vm.isValidURLForSearch("https://") == false)
        #expect(vm.isValidURLForSearch("notaurl") == false)
    }

    @Test("searchByURL toggles flags correctly (isSearching/lastSearchAttempted)")
    func testSearchFlagsToggle() async throws {
        let (vm, _, mockID) = try makeSUT()

        await withMock(id: mockID, { request in
            guard let url = request.url else { fatalError() }

            if request.httpMethod == "POST",
               url.absoluteString.contains("/api/alias") {
                let body = #"{ "alias":"S", "_links": { "self":"https://example.com", "short":"https://sho.rt/S" } }"#
                let resp = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)!
                return (resp, Data(body.utf8))
            }
            if request.httpMethod == "GET",
               url.absoluteString.contains("/api/alias/S") {
                let payload = Data(#"{ "url":"https://example.com" }"#.utf8)
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (resp, payload)
            }
            if url.host == "t0.gstatic.com", url.path.contains("faviconV2") {
                let resp = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: ["Content-Type":"text/plain"])!
                return (resp, Data())
            }
            let resp = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }) {
            #expect(vm.isSearching == false)
            #expect(vm.lastSearchAttempted == false)

            await vm.searchByURL("https://example.com")

            #expect(vm.isSearching == false)
            #expect(vm.lastSearchAttempted == true)
            #expect(vm.errorMessage == nil)
            #expect(vm.searchResult?.link.serverID == "S")
        }
    }

    @Test("clearSearch resets search state")
    func testClearSearchResets() async throws {
        let (vm, _, _) = try makeSUT()
        vm.searchResult = makeDisplayLink(serverID: "S", url: "https://s.com")
        vm.lastSearchAttempted = true
        vm.isSearching = true

        vm.clearSearch()

        #expect(vm.searchResult == nil)
        #expect(vm.lastSearchAttempted == false)
        #expect(vm.isSearching == false)
    }
}
