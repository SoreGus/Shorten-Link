//
//  LinkSectionView.swift
//  Link
//

import SwiftUI
import SwiftData

struct LinkSectionView: View {
    @EnvironmentObject var viewModel: LinkViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        if viewModel.displayLinks.isEmpty {
            ContentUnavailableView("No saved links", systemImage: "tray")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .accessibilityIdentifier("link_section_view_empty")
        } else {
            Section {
                ForEach(viewModel.displayLinks, id: \.link.serverID) { item in
                    LinkRow(displayLink: item)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let url = URL(string: item.url) { openURL(url) }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await viewModel.delete(serverID: item.link.serverID) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                .onDelete(perform: viewModel.delete(at:))
            } header: {
                Text("Saved Links")
            } footer: {
                Text("\(viewModel.displayLinks.count) item(s)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#if DEBUG
private enum LinkListViewPreviewFactory {
    static func makeViewModel(populated: Bool) -> LinkViewModel {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: StoredLink.self, configurations: config)
        let ctx = ModelContext(container)
        let service = LinkService(context: ctx)
        let vm = LinkViewModel(service: service)

        if populated {
            vm.displayLinks = [
                DisplayLink(
                    link: Link(serverID: "ABC123"),
                    title: "Apple",
                    url: "https://apple.com",
                    icon: .placeholderSystemName("apple.logo")
                ),
                DisplayLink(
                    link: Link(serverID: "XYZ999"),
                    title: "Swift",
                    url: "https://swift.org",
                    icon: .placeholderSystemName("swift")
                ),
                DisplayLink(
                    link: Link(serverID: "N1"),
                    title: "Example",
                    url: "https://example.com",
                    icon: .placeholderSystemName("globe")
                )
            ]
        }

        return vm
    }
}

struct LinkListView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationStack {
                LinkSectionView()
            }
            .environmentObject(LinkListViewPreviewFactory.makeViewModel(populated: false))
            .previewDisplayName("iPhone • Empty")
            #if os(iOS)
            .previewDevice(.init(rawValue: "iPhone 15 Pro"))
            #endif

            NavigationStack {
                LinkSectionView()
            }
            .environmentObject(LinkListViewPreviewFactory.makeViewModel(populated: true))
            .previewDisplayName("Populated")
            #if os(iOS)
            .previewDevice(.init(rawValue: "iPhone 15 Pro"))
            #endif
        }
    }
}
#endif
