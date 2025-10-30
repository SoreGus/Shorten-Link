//
//  LinkView.swift
//  Link
//

import SwiftUI
import SwiftData
import Combine

#if canImport(UIKit)
import UIKit
typealias NativeImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias NativeImage = NSImage
#endif

struct LinkView: View {
    @EnvironmentObject var viewModel: LinkViewModel
    @Environment(\.openURL) private var openURL

    @State private var urlInput: String = ""
    @State private var showError: Bool = false

    var body: some View {
        Group {
            if #available(iOS 16.0, macOS 13.0, *) {
                NavigationStack { content }
            } else {
                NavigationView { content }
            }
        }
        .onAppear { viewModel.loadAll() }
        .onChange(of: viewModel.errorMessage) { _, new in
            showError = (new != nil)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { showError = false }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }

    private var content: some View {
        List {
            Section {
                LinkControlsView(urlInput: $urlInput)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
            }

            if viewModel.isSearching || viewModel.searchResult != nil {
                Section {
                    SearchResultBannerView(urlInput: $urlInput)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }

            Section {
                if viewModel.displayLinks.isEmpty {
                    ContentUnavailableView(
                        "No saved links",
                        systemImage: "tray"
                    )
                    .frame(maxWidth: .infinity, alignment: .top)
                    .listRowInsets(EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16))
                    .listRowSeparator(.hidden)
                } else {
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
                }
            } header: {
                Text("Saved Links")
            } footer: {
                Text("\(viewModel.displayLinks.count) item(s)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Links")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.loadAll()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                        .glassEffect(.clear)
                }
            }
        }
        .listStyle(.inset)
    }
}

#if DEBUG
struct LinkView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LinkView()
                .environmentObject(
                    LinkViewModel(
                        service: LinkService(
                            context: try! ModelContext(ModelContainer(for: StoredLink.self))
                        )
                    )
                )
                .previewDisplayName("iPhone")

            LinkView()
                .environmentObject(
                    LinkViewModel(
                        service: LinkService(
                            context: try! ModelContext(ModelContainer(for: StoredLink.self))
                        )
                    )
                )
                .previewInterfaceOrientation(.landscapeLeft)
                .previewDisplayName("iPad/Mac (Unified List)")
        }
    }
}
#endif
