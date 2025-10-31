//
//  LinkApp.swift
//  Link
//

import SwiftUI
import SwiftData

@main
struct LinkApp: App {
    @StateObject private var viewModel: LinkViewModel
    private let interactor: LinkViewModelInteractor

    init() {
        let args = ProcessInfo.processInfo.arguments
        
        let isUITesting = args.contains("-uiTesting")
        let disableAnimations = args.contains("-disableAnimations")

        if disableAnimations {
            #if canImport(UIKit)
            UIView.setAnimationsEnabled(false)
            #endif
            CATransaction.setDisableActions(true)
        }

        do {
            let vm: LinkViewModel
            if isUITesting {
                vm = try LinkViewModelFactory.makeInMemory()
            } else {
                vm = try LinkViewModelFactory.makePersistent()
            }
            _viewModel = StateObject(wrappedValue: vm)
            interactor = LinkViewModelInteractor(viewModel: vm)
        } catch {
            fatalError("Failed to bootstrap LinkViewModel: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            LinkView()
                .environmentObject(viewModel)
                .onOpenURL { url in
                    interactor.handle(url: url)
                }
        }
    }
}
