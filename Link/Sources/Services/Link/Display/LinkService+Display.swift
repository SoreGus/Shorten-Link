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

                let iconSize = 128

                let loadServerID: @Sendable (String) async throws -> DisplayLink? = { [weak self] id in
                    guard let self else { return nil }
                    return try await self.load(serverID: id)
                }

                let fetchFaviconSoft: @Sendable (URL) async -> Data? = { [weak self] url in
                    guard let self else { return nil }
                    return await self.fetchFaviconData(siteURL: url, iconSize)
                }
                
                let fetchPageTitleSoft: @Sendable (URL) async -> String? = { [weak self] url in
                    guard let self else { return nil }
                    return await self.fetchPageTitle(siteURL: url)
                }

                await withTaskGroup(of: Void.self) { group in
                    for stored in storedLinks {
                        if Task.isCancelled { break }
                        group.addTask {
                            do {
                                guard let dl = try await loadServerID(stored.serverID) else { return }

                                continuation.yield(dl)
                                
                                if let url = URL(string: dl.url) {
                                    let title: String = await fetchPageTitleSoft(url) ?? dl.url
                                    if
                                        let data = await fetchFaviconSoft(url),
                                        let image = PlatformImage(data: data)
                                    {
                                        await continuation.yield(
                                            dl.withImage(
                                                icon: .platformImage(image),
                                                title: title
                                            )
                                        )
                                    } else {
                                        await continuation.yield(
                                            dl.withImage(
                                                icon: .placeholderSystemName("globe"),
                                                title: title
                                            )
                                        )
                                    }
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
    
    func fetchPageTitle(siteURL: URL) async -> String? {
        var req = URLRequest(url: siteURL)
        req.timeoutInterval = 15
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("Mozilla/5.0 (compatible; GPTBot/1.0)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  !data.isEmpty
            else {
                return nil
            }

            guard let html = String(data: data, encoding: .utf8) else { return nil }

            if let ogRange = html.range(of: #"<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']"#,
                                        options: .regularExpression),
               let match = html[ogRange].range(of: #"content=["']([^"']+)["']"#, options: .regularExpression) {
                let content = html[match]
                if let valRange = content.range(of: #"["']([^"']+)["']"#, options: .regularExpression) {
                    return String(content[valRange]).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                }
            }

            if let titleRange = html.range(of: "(?i)<title[^>]*>(.*?)</title>", options: .regularExpression) {
                let titleTag = html[titleRange]
                if let innerRange = titleTag.range(of: "(?i)>(.*?)<", options: .regularExpression) {
                    var title = String(titleTag[innerRange])
                    title = title.replacingOccurrences(of: ">", with: "")
                    title = title.replacingOccurrences(of: "<", with: "")
                    return title.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            return nil
        } catch {
            return nil
        }
    }
}
