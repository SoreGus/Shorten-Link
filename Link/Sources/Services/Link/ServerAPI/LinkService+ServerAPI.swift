//
//  LinkService+ServerAPI.swift
//  Link
//

import Foundation

private struct CreateRequestBody: Encodable, Sendable {
    let url: String
}

private struct CreateResponseBody: Decodable, Sendable {
    let alias: String
    struct Links: Decodable, Sendable {
        let self_: String
        let short: String
        private enum CodingKeys: String, CodingKey {
            case self_ = "self"
            case short
        }
    }
    let _links: Links
}

private struct LoadResponseBody: Decodable, Sendable {
    let url: String
}

private enum LinkAPI {
    static let base = "https://url-shortener-server.onrender.com"
    static let createPath = "/api/alias"
    static func loadPath(serverID: String) -> String { "/api/alias/\(serverID)" }
}

extension LinkService: LinkServerAPI {

    @MainActor
    public func create(url: String) async throws(LinkServerAPIError) -> Link {
        guard let endpoint = URL(string: LinkAPI.base + LinkAPI.createPath) else {
            throw .invalidURL
        }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            req.httpBody = try JSONEncoder().encode(CreateRequestBody(url: url))
        } catch {
            throw .encodingFailed(underlying: error)
        }
        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw .network(underlying: error)
        }
        guard let http = resp as? HTTPURLResponse else {
            throw .invalidResponse
        }
        switch http.statusCode {
        case 201, 200:
            do {
                let dto = try JSONDecoder().decode(CreateResponseBody.self, from: data)
                return Link(serverID: dto.alias)
            } catch {
                throw .decodingFailed(underlying: error)
            }
        case 404:
            throw .notFound
        default:
            throw .httpError(status: http.statusCode, body: String(data: data, encoding: .utf8))
        }
    }

    @MainActor
    public func load(serverID: String) async throws(LinkServerAPIError) -> DisplayLink {
        let allowed = serverID.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
        guard allowed else { throw .invalidURL }

        guard let endpoint = URL(string: LinkAPI.base + LinkAPI.loadPath(serverID: serverID)) else {
            throw .invalidURL
        }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "GET"

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw .network(underlying: error)
        }

        guard let http = resp as? HTTPURLResponse else {
            throw .invalidResponse
        }

        switch http.statusCode {
        case 200:
            do {
                let response = try JSONDecoder().decode(LoadResponseBody.self, from: data)
                return DisplayLink(
                    link: .init(
                        serverID: serverID
                    ),
                    url: response.url
                )
            } catch {
                throw .decodingFailed(underlying: error)
            }
        case 404:
            throw .notFound
        default:
            throw .httpError(status: http.statusCode, body: String(data: data, encoding: .utf8))
        }
    }
}
