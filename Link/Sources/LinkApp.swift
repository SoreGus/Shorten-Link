//
//  LinkApp.swift
//  Link
//
//  Created by Gustavo Soré on 29/10/25.
//

import SwiftUI
import SwiftData

@main
struct LinkApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    do {
                        let config = ModelConfiguration()
                        let container = try ModelContainer(for: StoredLink.self, configurations: config)
                        let context = ModelContext(container)
                        let service = LinkService(context: context)
                        Task {
                            do {
                                let link = try await service.create(url: "https://apple.com.br")
                                try await service.save(link: link)
                                let all = try await service.loadAll()
                                for link in all {
                                    print(link.serverID)
                                }
                            } catch {
                                print(error)
                            }
                        }
                    } catch {
                        print(error)
                    }
                }
        }
    }
}
