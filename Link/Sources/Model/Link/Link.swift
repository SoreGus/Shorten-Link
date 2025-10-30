//
//  Link.swift
//  Link
//

import Foundation

struct Link: Sendable, Hashable, Codable {
    let id: UUID
    let serverID: String
    
    init(
        id: UUID = .init(),
        serverID: String
    ) {
        self.id = id
        self.serverID = serverID
    }
}
