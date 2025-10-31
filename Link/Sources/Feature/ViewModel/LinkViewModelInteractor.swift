//
//  LinkViewModelInteractor.swift
//  Link
//
//  Created by Gustavo Soré on 31/10/25.
//

import Foundation

class LinkViewModelInteractor {
    let viewModel: LinkViewModel
    
    init(
        viewModel: LinkViewModel
    ) {
        self.viewModel = viewModel
    }
    
    func handle(
        url: URL
    ) {
        guard url.scheme == "link", url.host == "ui" else { return }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let q = comps?.queryItems ?? []
        func value(_ name: String) -> String? {
            q.first { $0.name == name }?.value
        }
        switch url.path {
            case "/set":
                if value("loading") == "on" {
                    viewModel.isSearching = true
                }
            case "/insert":
                if
                    let id = value("id"),
                    let title = value("title"),
                    let urlStr = value("url")
                {
                    let dl = DisplayLink(
                        link: Link(
                            serverID: id
                        ),
                        title: title,
                        url: urlStr,
                        icon: .placeholderSystemName("globe")
                    )
                    viewModel.displayLinks = [dl, dl]
                }
            case "/search":
            if
                let id = value("id"),
                let title = value("title"),
                let urlStr = value("url")
            {
                let dl = DisplayLink(
                    link: Link(
                        serverID: id
                    ),
                    title: title,
                    url: urlStr,
                    icon: .placeholderSystemName("globe")
                )
                viewModel.searchResult = dl
            }
            default:
                break
            }
    }
}
