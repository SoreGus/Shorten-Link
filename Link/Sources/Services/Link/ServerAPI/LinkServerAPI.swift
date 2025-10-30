//
//  LinkServerAPI.swift
//  Link
//
//  Created by Gustavo Soré on 29/10/25.
//

import Foundation

enum LinkServerAPIError: Error, Sendable {
    case invalidURL
    case encodingFailed(underlying: any Error)
    case decodingFailed(underlying: any Error)
    case invalidResponse
    case httpError(status: Int, body: String?)
    case notFound
    case network(underlying: any Error)
}

protocol LinkServerAPI {
    func create(url: String) async throws(LinkServerAPIError) -> Link
    func load(serverID: String) async throws(LinkServerAPIError) -> DisplayLink
}
