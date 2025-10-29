//
//  StoredLink.swift
//  Link
//
//  Created by Gustavo Soré on 29/10/25.
//

import Foundation
import SwiftData

@Model
class StoredLink {
    var id: UUID
    var serverID: String
    
    init(
        id: UUID = UUID(),
        serverID: String
    ) {
        self.id = id
        self.serverID = serverID
    }
}
