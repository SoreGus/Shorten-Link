//
//  LinkService.swift
//  Link
//

import Foundation
import SwiftData

actor LinkService {
    
    internal let context: ModelContext
    internal let session: URLSession
    
    init(
        context: ModelContext,
        session: URLSession = .shared
    ) {
        self.context = context
        self.session = session
    }
}
