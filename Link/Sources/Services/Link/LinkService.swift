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
    
    init(
        context: ModelContext
    ) {
        self.context = context
    }
}
