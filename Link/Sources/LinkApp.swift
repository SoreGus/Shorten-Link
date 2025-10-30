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
                        let config = ModelConfiguration(isStoredInMemoryOnly: false)
                        let container = try ModelContainer(for: StoredLink.self, configurations: config)
                        let context = ModelContext(container)
                        let service = LinkService(context: context)
                        Task {
                            do {
                                let link = try await service.create(url: "https://google.com.br")
                                try await service.save(link: link)
                            } catch {
                                print(error)
                            }
                            
//                            do {
//                                let display: DisplayLink = try await service.load(serverID: "158745607")
//                                print(display)
//                                let display2: DisplayLink = try await service.load(serverID: all.last?.serverID ?? "158745607")
//                                print(display2)
//                            } catch {
//                                print(error)
//                            }
                            print("### STREAM STARTED")
                            do {
                                for try await dl in service.loadAllDisplayLinksStream() {
                                    print(">>> RECEIVED:", dl.url, dl.icon == nil ? "[NO ICON]" : "[HAS ICON]")
                                }
                                print("### STREAM FINISHED")
                            } catch {
                                print("### STREAM FAILED:", error)
                            }
                        }
                    } catch {
                        print(error)
                    }
                }
        }
    }
}
