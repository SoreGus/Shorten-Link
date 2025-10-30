//
//  DisplayLink.swift
//  Link
//
//  Created by Gustavo Soré on 29/10/25.
//

#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
import SwiftUI
public typealias PlatformImage = NSImage
#endif

public enum DisplayIcon: Sendable, Equatable {
    case placeholderSystemName(String)
    case platformImage(PlatformImage)
}

struct DisplayLink: Sendable {
    let link: Link
    let url: String
    var icon: DisplayIcon?
    
    func withImage(
        icon: DisplayIcon
    ) -> Self {
        return .init(link: link, url: url, icon: icon)
    }
}

extension DisplayLink {
    static func loading(from stored: Link) -> DisplayLink {
        // Adapte aos campos reais do seu modelo
        DisplayLink(
            link: stored,
            url: "https://…",
            icon: nil
        )
    }
}
