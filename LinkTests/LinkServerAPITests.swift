//
//  LinkServerAPITests.swift
//  Link
//

import Testing
import Foundation
import SwiftData
@testable import Link

@MainActor
@Suite("LinkServerAPI (remote)")
struct LinkServerAPITests {

    // MARK: - Test Harness

    private func makeSUT() throws -> (sut: LinkService, context: ModelContext, mockID: String) {
        let mockID = UUID().uuidString

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Mock-ID": mockID] // <- isola handler por teste
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
        id mockID: String,
        _ handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data?),
        perform body: @escaping () async throws -> Void
    ) async rethrows {
        MockURLProtocol.set(mockID, handler)
        defer { MockURLProtocol.clear(mockID) }
        try await body()
        await Task.yield()
    }

    // MARK: - Tests

    @Test("create returns Link on 201 with alias")
    func testCreateSuccess() async throws {
        let (sut, _, mockID) = try makeSUT()
        let payload = Data(#"""
        {
          "alias":"158745607",
          "_links": {
            "self":"https://soregus.com.br/panel/reset",
            "short":"https://url-shortener-server.onrender.com/api/alias/158745607"
          }
        }
        """#.utf8)

        try await withMock(id: mockID, { request in
            let url = request.url!
            let response = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }) {
            let link = try await sut.create(url: "https://soregus.com.br/panel/reset")
            #expect(link.serverID == "158745607")
        }
    }

    @Test("create throws notFound on 404")
    func testCreateNotFound() async throws {
        let (sut, _, mockID) = try makeSUT()

        await withMock(id: mockID, { request in
            let url = request.url!
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }) {
            do {
                _ = try await sut.create(url: "https://example.com/x")
                Issue.record("Expected notFound")
            } catch LinkServerAPIError.notFound {
                #expect(true)
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    @Test("create throws decodingFailed on malformed JSON")
    func testCreateDecodingFailed() async throws {
        let (sut, _, mockID) = try makeSUT()
        let badJSON = Data(#"{"aliasx":123}"#.utf8)

        await withMock(id: mockID, { request in
            let url = request.url!
            let response = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (response, badJSON)
        }) {
            do {
                _ = try await sut.create(url: "https://example.com")
                Issue.record("Expected decodingFailed")
            } catch LinkServerAPIError.decodingFailed {
                #expect(true)
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    @Test("load returns Link on 200")
    func testLoadSuccess() async throws {
        let (sut, _, mockID) = try makeSUT()
        let payload = Data(#"{"url":"https://soregus.com.br/panel/reset"}"#.utf8)

        try await withMock(id: mockID, { request in
            let url = request.url!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }) {
            let link = try await sut.load(serverID: "abc123")
            #expect(link.link.serverID == "abc123")
        }
    }

    @Test("load throws notFound on 404")
    func testLoadNotFound() async throws {
        let (sut, _, mockID) = try makeSUT()

        await withMock(id: mockID, { request in
            let url = request.url!
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }) {
            do {
                _ = try await sut.load(serverID: "missing")
                Issue.record("Expected notFound")
            } catch LinkServerAPIError.notFound {
                #expect(true)
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    @Test("invalidURL when serverID has spaces")
    func testInvalidURLOnBadServerID() async throws {
        let (sut, _, _) = try makeSUT()
        do {
            _ = try await sut.load(serverID: "bad id with spaces")
            Issue.record("Expected invalidURL")
        } catch LinkServerAPIError.invalidURL {
            #expect(true)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("network error maps to LinkServerAPIError.network")
    func testNetworkError() async throws {
        let (sut, _, mockID) = try makeSUT()

        struct Dummy: Error {}
        try await withMock(id: mockID, { _ in
            throw Dummy()
        }) {
            do {
                _ = try await sut.create(url: "https://example.com")
                Issue.record("Expected network error")
            } catch LinkServerAPIError.network {
                #expect(true)
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }
}
