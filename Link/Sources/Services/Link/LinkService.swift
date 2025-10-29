//
//  LinkService.swift
//  Link
//
//  Created by Gustavo Soré on 29/10/25.
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
