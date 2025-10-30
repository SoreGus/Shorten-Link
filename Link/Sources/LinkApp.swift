//
//  LinkApp.swift
//  Link
//

import SwiftUI
import SwiftData

@main
struct LinkApp: App {
    @State private var container: ModelContainer
    @State private var service: LinkService

    init() {
        do {
            let config = ModelConfiguration()
            let container = try ModelContainer(for: StoredLink.self, configurations: config)
            _container = State(initialValue: container)
            _service = State(initialValue: LinkService(context: ModelContext(container)))
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            LinkView()
                .environmentObject(LinkViewModel(service: service))
        }
    }
}
