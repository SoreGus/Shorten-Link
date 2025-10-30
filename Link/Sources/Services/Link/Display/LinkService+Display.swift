//
//  LinkService+Display.swift
//  Link
//

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
import SwiftUI
#endif

extension LinkService: DisplayListProtocol {

    @MainActor
    func loadAllDisplayLinksStream() -> AsyncThrowingStream<DisplayLink, Error> {
        AsyncThrowingStream<DisplayLink, Error>(
            DisplayLink.self,
            bufferingPolicy: .unbounded
        ) { continuation in
            Task {
                let storedLinks: [Link]
                do {
                    storedLinks = try await self.loadAll()
                } catch let e as LinkRepositoryError {
                    continuation.finish(throwing: DisplayListError.storedLinks(e))
                    return
                } catch {
                    continuation.finish(throwing: error)
                    return
                }

                let iconSize = 64

                let loadServerID: @Sendable (String) async throws -> DisplayLink? = { [weak self] id in
                    guard let self else { return nil }
                    return try await self.load(serverID: id) // @MainActor; hop automático
                }

                let fetchFaviconSoft: @Sendable (URL) async -> Data? = { [weak self] url in
                    guard let self else { return nil }
                    return await self.fetchFaviconData(siteURL: url, iconSize)
                }

                await withTaskGroup(of: Void.self) { group in
                    for stored in storedLinks {
                        if Task.isCancelled { break }
                        group.addTask {
                            do {
                                guard let dl = try await loadServerID(stored.serverID) else { return }

                                continuation.yield(dl)

                                if let url = URL(string: dl.url),
                                   let data = await fetchFaviconSoft(url),
                                   let image = PlatformImage(data: data) {
                                    await continuation.yield(dl.withImage(icon: .platformImage(image)))
                                }

                            } catch {
                                return
                            }
                        }
                    }

                    for await _ in group {
                        if Task.isCancelled { break }
                    }
                }

                continuation.finish()
            }
        }
    }

    func fetchFaviconData(siteURL: URL, _ size: Int = 64) async -> Data? {
        var comps = URLComponents(string: "https://t0.gstatic.com/faviconV2")!
        comps.queryItems = [
            .init(name: "client", value: "SOCIAL"),
            .init(name: "type", value: "FAVICON"),
            .init(name: "fallback_opts", value: "TYPE,SIZE,URL"),
            .init(name: "url", value: siteURL.absoluteString),
            .init(name: "size", value: String(size))
        ]
        guard let url = comps.url else { return nil }

        var req = URLRequest(url: url)
        req.cachePolicy = .returnCacheDataElseLoad
        req.timeoutInterval = 15

        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            guard !data.isEmpty else { return nil }

            let mime = http.value(forHTTPHeaderField: "Content-Type")?.lowercased()
            guard mime?.hasPrefix("image/") ?? true else { return nil }

            return data
        } catch {
            return nil
        }
    }
}
