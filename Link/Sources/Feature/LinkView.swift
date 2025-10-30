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
                #if os(iOS)
                .navigationViewStyle(StackNavigationViewStyle())
                #endif
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
        VStack(spacing: 16) {
            controls
            searchResultBanner
            listSection
        }
        .padding()
        .navigationTitle("Links")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.loadAll()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    private var listSection: some View {
        Group {
            if viewModel.displayLinks.isEmpty {
                ContentUnavailableView("No saved links", systemImage: "tray")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                List {
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
                #if os(iOS)
                .listStyle(.insetGrouped)
                #else
                .listStyle(.inset)
                #endif
            }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add by URL").font(.headline)

            HStack(spacing: 8) {
                TextField("Paste a URL (e.g. https://example.com)", text: $urlInput)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .disabled(viewModel.isSearching || viewModel.isSavingSearchResult)
                    .onSubmit { submitSearch() }

                Button(action: submitSearch) {
                    if viewModel.isSearching {
                        ProgressView().controlSize(.small).padding(.horizontal, 8)
                    } else {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.isValidURLForSearch(urlInput)
                          || viewModel.isSearching
                          || viewModel.isSavingSearchResult)
            }
        }
    }

    private var searchResultBanner: some View {
        Group {
            if viewModel.isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Searching…").foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel") { viewModel.clearSearch() }
                }
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if let result = viewModel.searchResult {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 12) {
                        IconView(icon: result.icon)
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 0.5))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.link.serverID).font(.headline).lineLimit(1)
                            Text(result.url).foregroundStyle(.secondary).font(.subheadline).lineLimit(1)
                        }

                        Spacer()

                        let alreadySaved = viewModel.displayLinks.contains { $0.link.serverID == result.link.serverID }
                        Button {
                            Task {
                                await viewModel.saveCurrentSearchResult()
                                urlInput = ""
                            }
                        } label: {
                            if viewModel.isSavingSearchResult {
                                ProgressView()
                            } else {
                                Label(alreadySaved ? "Saved" : "Save",
                                      systemImage: alreadySaved ? "checkmark.circle.fill" : "tray.and.arrow.down.fill")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(alreadySaved || viewModel.isSavingSearchResult)
                    }

                    HStack(spacing: 12) {
                        Button {
                            if let url = URL(string: result.url) { openURL(url) }
                        } label: {
                            Label("Open", systemImage: "safari")
                        }
                        .buttonStyle(.bordered)

                        Button(role: .cancel) {
                            viewModel.clearSearch()
                        } label: {
                            Label("Clear", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isSavingSearchResult)
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut, value: viewModel.isSearching)
        .animation(.easeInOut, value: viewModel.searchResult != nil)
    }

    private func submitSearch() {
        let raw = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard viewModel.isValidURLForSearch(raw) else { return }
        Task { await viewModel.trySearch(rawInput: raw) }
    }
}

private struct LinkRow: View {
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

private struct IconView: View {
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
                .previewDisplayName("iPad/Mac (Unified Look)")
        }
    }
}
#endif
