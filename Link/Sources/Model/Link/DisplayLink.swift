//
//  DisplayLink.swift
//  Link
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
    var title: String
    let url: String
    var icon: DisplayIcon?
    
    func withImage(
        icon: DisplayIcon,
        title: String = "Title"
    ) -> Self {
        return .init(link: link, title: title, url: url, icon: icon)
    }
}
