//
//  LinkControlsView.swift
//  Link
//

import SwiftUI
import SwiftData

struct LinkControlsView: View {
    @EnvironmentObject var viewModel: LinkViewModel
    @Binding var urlInput: String
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search by URL")
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.bottom, 2)
                .accessibilityIdentifier("search-by-url-text")

            TextField("Paste a URL", text: $urlInput)
                .textFieldStyle(.roundedBorder)
                .focused($isFieldFocused)
                .submitLabel(.search)
                .disabled(viewModel.isSearching || viewModel.isSavingSearchResult)
                .onSubmit { submit() }
                .overlay(alignment: .trailing) {
                    if !urlInput.isEmpty {
                        Button {
                            urlInput = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.secondary)
                                .padding(.trailing, 8)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear text")
                    }
                }
                .accessibilityIdentifier("paste-a-url-textfield")

            Button(action: submit) {
                if viewModel.isSearching {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Searching…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("button-searching-text")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Label("Search", systemImage: "magnifyingglass")
                        .font(.headline)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle( .white)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("button-search-label")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.isValidURLForSearch(urlInput)
                      || viewModel.isSearching
                      || viewModel.isSavingSearchResult)
            .accessibilityIdentifier("search-button")
        }
        .padding(16)
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.quaternary, lineWidth: 0.5)
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
        .animation(.easeInOut, value: viewModel.isSearching)
    }

    private func submit() {
        let raw = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard viewModel.isValidURLForSearch(raw) else { return }
        Task {
            await viewModel.trySearch(rawInput: raw)
            isFieldFocused = false
        }
    }
}

#if DEBUG
struct LinkControlsView_Previews: PreviewProvider {
    static var previews: some View {
        let previewVM = try! LinkViewModelFactory.makeInMemory()

        return Group {
            LinkControlsView(urlInput: .constant("https://apple.com"))
                .environmentObject(previewVM)
                .environment(\.colorScheme, .light)
                .padding()
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Light Mode")
            
            LinkControlsView(urlInput: .constant(""))
                .environmentObject(previewVM)
                .environment(\.colorScheme, .light)
                .padding()
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Empty URL Dark Mode")
            
            LinkControlsView(urlInput: .constant(""))
                .environmentObject(previewVM)
                .environment(\.colorScheme, .dark)
                .padding()
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Empty URL Dark Mode")

            LinkControlsView(urlInput: .constant("https://swift.org"))
                .environmentObject(previewVM)
                .environment(\.colorScheme, .dark)
                .padding()
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Dark Mode")
        }
    }
}
#endif
