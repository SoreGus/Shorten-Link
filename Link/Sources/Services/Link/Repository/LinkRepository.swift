//
//  LinkRepository.swift
//  Link
//

enum LinkRepositoryError: Error {
    case notImplemented
    case notFound
    case duplicateServerID
    case persistenceFailed(underlying: any Error)
}

protocol LinkRepository {
    func save(
        link: Link
    ) async throws(LinkRepositoryError)
    func loadAll() async throws(LinkRepositoryError) -> [Link]
    func delete(serverID: String) async throws(LinkRepositoryError)
}
