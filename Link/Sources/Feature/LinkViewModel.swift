//
//  LinkViewModel.swift
//  Link
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
final class LinkViewModel: ObservableObject {
    
    @Published var displayLinks: [DisplayLink] = []
    @Published var errorMessage: String?
    @Published var isSearching: Bool = false
    @Published var searchResult: DisplayLink? = nil
    @Published var lastSearchAttempted: Bool = false
    @Published var isSavingSearchResult: Bool = false

    private let service: LinkService
    private var loadTask: Task<Void, Never>?

    init(
        service: LinkService
    ) {
        self.service = service
    }

    deinit {
        loadTask?.cancel()
    }

    func loadAll() {
        loadTask?.cancel()
        errorMessage = nil

        loadTask = Task { [weak self] in
            guard let self else { return }
            var indexByID: [String: Int] = [:]
            self.displayLinks.removeAll()

            do {
                for try await item in self.service.loadAllDisplayLinksStream() {
                    self.upsert(item, indexByID: &indexByID)
                }
            } catch {
                self.errorMessage = Self.humanize(error)
            }
        }
    }

    func searchByURL(_ urlString: String) async {
        errorMessage = nil
        isSearching = true
        lastSearchAttempted = false
        defer {
            isSearching = false
            lastSearchAttempted = true
        }

        do {
            let link = try await service.create(url: urlString)
            var dl = try await service.load(serverID: link.serverID)

            if let url = URL(string: dl.url),
               let data = await service.fetchFaviconData(siteURL: url, 64) {
                #if canImport(UIKit)
                if let img = UIImage(data: data) {
                    dl = dl.withImage(icon: .platformImage(img))
                }
                #else
                if let img = NSImage(data: data) {
                    dl = dl.withImage(icon: .platformImage(img))
                }
                #endif
            }

            searchResult = dl
        } catch {
            errorMessage = Self.humanize(error)
            searchResult = nil
        }
    }

    func saveCurrentSearchResult() async {
        guard let result = searchResult else { return }
        errorMessage = nil
        isSavingSearchResult = true
        defer { isSavingSearchResult = false }

        do {
            try await service.save(link: result.link)
            insertOrPromoteToTop(result)
            clearSearch()
        } catch {
            errorMessage = Self.humanize(error)
        }
    }

    func clearSearch() {
        searchResult = nil
        lastSearchAttempted = false
        isSearching = false
    }

    func delete(serverID: String) async {
        errorMessage = nil

        guard let idx = displayLinks.firstIndex(where: { $0.link.serverID == serverID }) else {
            return
        }

        let snapshot = displayLinks
        displayLinks.remove(at: idx)

        do {
            try await service.delete(serverID: serverID)
        } catch {
            displayLinks = snapshot
            errorMessage = Self.humanize(error)
        }
    }

    func delete(at offsets: IndexSet) {
        Task {
            for index in offsets.sorted(by: >) {
                guard displayLinks.indices.contains(index) else { continue }
                let id = displayLinks[index].link.serverID
                await delete(serverID: id)
            }
        }
    }

    private func upsert(_ item: DisplayLink) {
        if let idx = displayLinks.firstIndex(where: { $0.link.serverID == item.link.serverID }) {
            displayLinks[idx] = item
        } else {
            displayLinks.append(item)
        }
    }

    private func upsert(_ item: DisplayLink, indexByID: inout [String: Int]) {
        let id = item.link.serverID
        if let idx = indexByID[id] {
            displayLinks[idx] = item
        } else {
            displayLinks.append(item)
            indexByID[id] = displayLinks.count - 1
        }
    }

    private func insertOrPromoteToTop(_ item: DisplayLink) {
        if let idx = displayLinks.firstIndex(where: { $0.link.serverID == item.link.serverID }) {
            displayLinks[idx] = item
            if idx != 0 {
                let updated = displayLinks.remove(at: idx)
                displayLinks.insert(updated, at: 0)
            }
        } else {
            displayLinks.insert(item, at: 0)
        }
    }

    private static func humanizeServerAPIError(_ error: LinkServerAPIError) -> String {
        switch error {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response"
        case .notFound: return "Not found"
        case .decodingFailed(let underlying): return "Decoding failed: \(underlying)"
        case .encodingFailed(let underlying): return "Encoding failed: \(underlying)"
        case .httpError(let status, _): return "HTTP error: \(status)"
        case .network(let underlying): return "Network error: \(underlying)"
        }
    }

    private static func humanize(_ error: Error) -> String {
        if let e = error as? DisplayListError {
            switch e {
            case .storedLinks(let underlying): return "Storage error: \(underlying)"
            case .httpStatus(let code): return "HTTP error: \(code)"
            case .emptyData: return "Empty data"
            case .invalidMime(let mime): return "Invalid MIME type: \(mime ?? "")"
            case .invalidRequestURL: return "Invalid request URL"
            case .notImplemented: return "Not Implemented"
            case .serverError(let err): return humanizeServerAPIError(err)
            }
        }
        if let e = error as? LinkServerAPIError {
            return humanizeServerAPIError(e)
        }
        if let e = error as? LinkRepositoryError {
            switch e {
            case .duplicateServerID: return "Duplicate link"
            case .notFound: return "Local item not found"
            case .persistenceFailed(let underlying): return "Persistence failed: \(underlying)"
            case .notImplemented: return "Not Implemented"
            }
        }
        return error.localizedDescription
    }
}


extension LinkViewModel {
    func isValidURLForSearch(_ raw: String) -> Bool {
        normalizedURL(from: raw) != nil
    }

    func trySearch(rawInput: String) async {
        guard let url = normalizedURL(from: rawInput) else {
            errorMessage = "Invalid URL"
            return
        }
        await searchByURL(url.absoluteString)
    }

    private func normalizedURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let candidate: String = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard var comps = URLComponents(string: candidate) else { return nil }

        if comps.scheme == nil { comps.scheme = "https" }
        guard let scheme = comps.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }

        guard let host = comps.host, !host.isEmpty, isLikelyValidHost(host) else { return nil }

        return comps.url
    }

    private func isLikelyValidHost(_ host: String) -> Bool {
        let h = host.lowercased()
        if h == "localhost" { return true }
        if h.contains(":") { return true } // IPv6 literal
        // exige ao menos um ponto (ex.: example.com)
        return h.split(separator: ".").count >= 2
    }
}
