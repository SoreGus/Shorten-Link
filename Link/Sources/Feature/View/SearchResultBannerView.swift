//
//  SearchResultBannerView.swift
//  Link
//

import SwiftUI

struct SearchResultBannerView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var viewModel: LinkViewModel
    @Binding var urlInput: String

    var body: some View {
        Group {
            if viewModel.isSearching {
                searchingRow
            } else if let result = viewModel.searchResult {
                resultRow(result)
            }
        }
        .animation(.easeInOut, value: viewModel.isSearching)
        .animation(.easeInOut, value: viewModel.searchResult != nil)
    }

    // MARK: - Searching

    private var searchingRow: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("Searching…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("Cancel") { viewModel.clearSearch() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary, lineWidth: 0.5))
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowSeparator(.hidden)
    }

    // MARK: - Result

    private func resultRow(_ result: DisplayLink) -> some View {
        VStack(alignment: .leading, spacing: 12) {

            // Linha 1 — Ícone + textos (mesma linha)
            HStack(alignment: .center, spacing: 12) {
                IconView(icon: result.icon)
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.link.serverID)
                        .font(.headline)
                        .lineLimit(1)
                    Text(result.url)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            // Linha 2 — Save sozinho
            saveButton(for: result)
                .frame(maxWidth: .infinity, alignment: .center)

            // Linha 3 — Open e Clear distribuídos igualmente
            HStack(spacing: 10) {
                Button {
                    if let url = URL(string: result.url) { openURL(url) }
                } label: {
                    Label("Open", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(role: .cancel) {
                    viewModel.clearSearch()
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isSavingSearchResult)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary, lineWidth: 0.5))
        .transition(.opacity.combined(with: .move(edge: .top)))
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowSeparator(.hidden)
    }

    // MARK: - Components

    private func saveButton(for result: DisplayLink) -> some View {
        let alreadySaved = viewModel.displayLinks.contains { $0.link.serverID == result.link.serverID }

        return Button {
            Task {
                await viewModel.saveCurrentSearchResult()
                urlInput = ""
            }
        } label: {
            Group {
                if viewModel.isSavingSearchResult {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                } else {
                    Label(
                        alreadySaved ? "Saved" : "Save",
                        systemImage: alreadySaved ? "checkmark.circle.fill" : "tray.and.arrow.down.fill"
                    )
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(alreadySaved ? .green : .white)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
        .disabled(alreadySaved || viewModel.isSavingSearchResult)
    }
}

#if DEBUG
private struct _SearchResultBannerPreviewHost: View {
    @State private var urlInput: String
    @StateObject private var viewModel: LinkViewModel

    init(state: StateKind) {
        let vm = try! LinkViewModelFactory.make(isMemory: true)
        switch state {
        case .searching:
            vm.isSearching = true
            self._urlInput = State(initialValue: "https://example.com")
        case .result:
            let link = Link(serverID: "NEWID")
            let result = DisplayLink(
                link: link,
                title: "Example OG Title",
                url: "https://example.com",
                icon: .placeholderSystemName("globe")
            )
            vm.searchResult = result
            self._urlInput = State(initialValue: "https://example.com")
        }
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        List {
            Section {
                SearchResultBannerView(urlInput: $urlInput)
                    .environmentObject(viewModel)
            } footer: {
                Text("Preview footer")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.inset)
        .padding(.vertical, 8)
    }

    enum StateKind { case searching, result }
}

struct SearchResultBannerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            _SearchResultBannerPreviewHost(state: .searching)
                .previewDisplayName("Searching…")
            _SearchResultBannerPreviewHost(state: .result)
                .previewDisplayName("Result")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
