//
//  LinkApp.swift
//  Link
//

import SwiftUI
import SwiftData

@main
struct LinkApp: App {
    @State private var viewModel: LinkViewModel

    init() {
        do {
            _viewModel = State(initialValue: try LinkViewModelFactory.makePersistent())
        } catch {
            fatalError("Failed to bootstrap LinkViewModel: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            LinkView()
                .environmentObject(viewModel)
        }
    }
}
