//
//  LinkViewModelFactory.swift
//  Link
//


import SwiftUI
import SwiftData

enum LinkStorage {
    case persistent
    case inMemory
}

@MainActor
enum LinkViewModelFactory {

    static func make(
        isMemory: Bool = false,
        session: URLSession = .shared,
        preload: [Link] = []
    ) throws -> LinkViewModel {
        let container = try makeContainer(isMemory: isMemory)
        let context = ModelContext(container)
        let service = LinkService(context: context, session: session)
        let vm = LinkViewModel(service: service)

        if !preload.isEmpty {
            Task {
                for link in preload {
                    try? await service.save(link: link)
                }
                await MainActor.run { vm.loadAll() }
            }
        }

        return vm
    }
    
    static func makePersistent(session: URLSession = .shared, preload: [Link] = []) throws -> LinkViewModel {
        try make(isMemory: false, session: session, preload: preload)
    }

    static func makeInMemory(session: URLSession = .shared, preload: [Link] = []) throws -> LinkViewModel {
        try make(isMemory: true, session: session, preload: preload)
    }

    private static func makeContainer(isMemory: Bool) throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: isMemory)
        return try ModelContainer(for: StoredLink.self, configurations: config)
    }
}
