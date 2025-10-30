//
//  LinkService+Repository.swift
//  Link
//

import Foundation
import SwiftData

extension LinkService: LinkRepository {
    func save(link: Link) async throws(LinkRepositoryError) {
        do {
            if let existingByID = try fetchByID(link.id) {
                existingByID.serverID = link.serverID
                try context.save()
                return
            }
            if try fetchByServerID(link.serverID) != nil {
                throw LinkRepositoryError.duplicateServerID
            }
            let stored = StoredLink(id: link.id, serverID: link.serverID)
            context.insert(stored)
            try context.save()
        } catch let e as LinkRepositoryError {
            throw e
        } catch {
            throw .persistenceFailed(underlying: error)
        }
    }

    func loadAll() async throws(LinkRepositoryError) -> [Link] {
        do {
            let stored = try context.fetch(FetchDescriptor<StoredLink>())
            var links: [Link] = []
            links.reserveCapacity(stored.count)
            for s in stored {
                await links.append(Link(id: s.id, serverID: s.serverID))
            }
            return links
        } catch let e as LinkRepositoryError {
            throw e
        } catch {
            throw .persistenceFailed(underlying: error)
        }
    }

    func delete(serverID: String) async throws(LinkRepositoryError) {
        do {
            guard let stored = try fetchByServerID(serverID) else {
                throw LinkRepositoryError.notFound
            }
            context.delete(stored)
            try context.save()
        } catch let e as LinkRepositoryError {
            throw e
        } catch {
            throw .persistenceFailed(underlying: error)
        }
    }

    private func fetchByID(_ id: UUID) throws -> StoredLink? {
        let predicate = #Predicate<StoredLink> { $0.id == id }
        var descriptor = FetchDescriptor<StoredLink>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchByServerID(_ serverID: String) throws -> StoredLink? {
        let predicate = #Predicate<StoredLink> { $0.serverID == serverID }
        var descriptor = FetchDescriptor<StoredLink>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
