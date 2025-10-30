//
//  LinkRow.swift
//  Link
//

import SwiftUI

struct LinkRow: View {
    let displayLink: DisplayLink

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                IconView(icon: displayLink.icon)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 0.5))

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayLink.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(displayLink.url)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 16)
            }
            .padding(8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
        .listRowSeparator(.hidden)
    }
}

#if DEBUG
struct LinkRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LinkRow(
                displayLink: DisplayLink(
                    link: Link(serverID: "A1B2C3"),
                    title: "Apple Developer",
                    url: "https://developer.apple.com",
                    icon: .placeholderSystemName("apple.logo")
                )
            )
            .previewDisplayName("Com Ícone (System)")
            .padding()
            .previewLayout(.sizeThatFits)

            LinkRow(
                displayLink: DisplayLink(
                    link: Link(serverID: "D4E5F6"),
                    title: "Swift.org",
                    url: "https://swift.org",
                    icon: nil
                )
            )
            .previewDisplayName("Sem Ícone")
            .padding()
            .previewLayout(.sizeThatFits)

            #if canImport(UIKit)
            let image = UIGraphicsImageRenderer(size: CGSize(width: 52, height: 52)).image { ctx in
                UIColor.systemTeal.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 52, height: 52))
            }
            LinkRow(
                displayLink: DisplayLink(
                    link: Link(serverID: "Z9Y8X7"),
                    title: "Example.com",
                    url: "https://example.com",
                    icon: .platformImage(image)
                )
            )
            .previewDisplayName("Com Ícone Customizado (UIKit)")
            .padding()
            .previewLayout(.sizeThatFits)
            #elseif canImport(AppKit)
            let nsImage: NSImage = {
                let size = NSSize(width: 52, height: 52)
                let image = NSImage(size: size)
                image.lockFocus()
                NSColor.systemTeal.setFill()
                NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
                image.unlockFocus()
                return image
            }()
            LinkRow(
                displayLink: DisplayLink(
                    link: Link(serverID: "Z9Y8X7"),
                    title: "Example.com",
                    url: "https://example.com",
                    icon: .platformImage(nsImage)
                )
            )
            .previewDisplayName("Com Ícone Customizado (AppKit)")
            .padding()
            .previewLayout(.sizeThatFits)
            #endif
        }
    }
}
#endif
