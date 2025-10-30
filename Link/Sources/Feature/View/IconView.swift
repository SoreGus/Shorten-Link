//
//  IconView.swift
//  Link
//

import SwiftUI

struct IconView: View {
    let icon: DisplayIcon?

    var body: some View {
        switch icon {
        case .platformImage(let anyImage):
            #if canImport(UIKit)
            Image(uiImage: anyImage).resizable().scaledToFill()
            #elseif canImport(AppKit)
            Image(nsImage: anyImage).resizable().scaledToFill()
            #else
            placeholder
            #endif

        case .placeholderSystemName(let name):
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .padding(6)
                .foregroundStyle(.secondary)

        case .none:
            placeholder
        }
    }

    private var placeholder: some View {
        Image(systemName: "globe")
            .resizable()
            .scaledToFit()
            .padding(6)
            .foregroundStyle(.secondary)
    }
}

#if DEBUG
import SwiftUI

struct IconView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: 16) {
                Text("Platform Image")
                    .font(.headline)
                
                #if canImport(UIKit)
                let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { ctx in
                    UIColor.systemBlue.setFill()
                    ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
                }
                IconView(icon: .platformImage(image))
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                #elseif canImport(AppKit)
                let nsImage: NSImage = {
                    let size = NSSize(width: 64, height: 64)
                    let image = NSImage(size: size)
                    image.lockFocus()
                    NSColor.systemBlue.setFill()
                    NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
                    image.unlockFocus()
                    return image
                }()
                IconView(icon: .platformImage(nsImage))
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                #endif
                
                Divider()
                
                Text("System Placeholder")
                    .font(.headline)
                IconView(icon: .placeholderSystemName("link"))
                    .frame(width: 64, height: 64)
                
                Divider()
                
                Text("Default Placeholder")
                    .font(.headline)
                IconView(icon: nil)
                    .frame(width: 64, height: 64)
            }
            .padding()
            .previewLayout(.sizeThatFits)
            .previewDisplayName("IconView – All States")
        }
    }
}
#endif
