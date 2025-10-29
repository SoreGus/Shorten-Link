//
//  Link.swift
//  Link
//
//  Created by Gustavo Soré on 29/10/25.
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
