//
//  LinkRepositoryTests.swift
//  Link
//

import Testing
import Foundation
import SwiftData
@testable import Link

@MainActor
@Suite("LinkRepository (SwiftData, in-memory)")
struct LinkRepositoryTests {
    private func makeService() throws -> LinkService {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: StoredLink.self, configurations: config)
        let context = ModelContext(container)
        return LinkService(context: context)
    }

    private func makeLink(serverID: String, id: UUID = .init()) -> Link {
        Link(id: id, serverID: serverID)
    }

    @Test("save inserts a new record")
    func testSaveInsertsNew() async throws {
        let service = try makeService()
        let l = makeLink(serverID: "srv-1")
        try await service.save(link: l)
        let all = try await service.loadAll()
        #expect(all.count == 1)
        #expect(all.first?.id == l.id)
        #expect(all.first?.serverID == l.serverID)
    }

    @Test("save updates by existing id")
    func testSaveUpdatesByID() async throws {
        let service = try makeService()
        let id = UUID()
        let a = makeLink(serverID: "srv-1", id: id)
        try await service.save(link: a)
        let b = makeLink(serverID: "srv-1-updated", id: id)
        try await service.save(link: b)
        let all = try await service.loadAll()
        let got = all.first(where: { $0.id == id })
        #expect(got != nil)
        #expect(got?.serverID == "srv-1-updated")
        #expect(all.count == 1)
    }

    @Test("save throws duplicateServerID when serverID already exists")
    func testSaveDuplicateServerID() async throws {
        let service = try makeService()
        try await service.save(link: makeLink(serverID: "dup-1"))
        do {
            try await service.save(link: makeLink(serverID: "dup-1"))
            Issue.record("Expected duplicateServerID but no error was thrown.")
        } catch LinkRepositoryError.duplicateServerID {
            #expect(true)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("loadAll returns all records")
    func testLoadAllReturnsAll() async throws {
        let service = try makeService()
        let l1 = makeLink(serverID: "a")
        let l2 = makeLink(serverID: "b")
        let l3 = makeLink(serverID: "c")
        try await service.save(link: l1)
        try await service.save(link: l2)
        try await service.save(link: l3)
        let all = try await service.loadAll()
        #expect(all.count == 3)
        #expect(Set(all.map { $0.serverID }) == Set(["a","b","c"]))
    }

    @Test("loadAll returns empty when storage is empty")
    func testLoadAllEmpty() async throws {
        let service = try makeService()
        let all = try await service.loadAll()
        #expect(all.isEmpty)
    }

    @Test("delete removes by serverID")
    func testDeleteSuccess() async throws {
        let service = try makeService()
        try await service.save(link: makeLink(serverID: "to-delete"))
        try await service.delete(serverID: "to-delete")
        let all = try await service.loadAll()
        #expect(all.isEmpty)
    }

    @Test("delete throws notFound for missing serverID")
    func testDeleteNotFound() async throws {
        let service = try makeService()
        do {
            try await service.delete(serverID: "missing")
            Issue.record("Expected notFound but no error was thrown.")
        } catch LinkRepositoryError.notFound {
            #expect(true)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
