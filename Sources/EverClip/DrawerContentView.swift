import SwiftUI

struct DrawerContentView: View {
    @ObservedObject var viewModel: DrawerViewModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            // Main layout
            HStack(spacing: 0) {
                if viewModel.isSidebarVisible {
                    SidebarView(viewModel: viewModel)
                        .frame(width: 170)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    Divider().opacity(0.2)
                }

                VStack(spacing: 0) {
                    FilterBarView(viewModel: viewModel, searchFocused: $searchFocused)
                    Divider().opacity(0.2)
                    mainContent
                    Divider().opacity(0.2)
                    StatusBarView(viewModel: viewModel)
                }
            }

            // Quick Look overlay
            if let entry = viewModel.quickLookEntry {
                QuickLookPreviewView(entry: entry) {
                    viewModel.quickLookEntry = nil
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.quickLookEntry != nil)
        .focusable()
        .onKeyPress(.escape) {
            if viewModel.quickLookEntry != nil {
                viewModel.quickLookEntry = nil
            } else {
                viewModel.dismiss()
            }
            return .handled
        }
        .onKeyPress(.leftArrow)  { viewModel.move(-1);  return .handled }
        .onKeyPress(.rightArrow) { viewModel.move(1);   return .handled }
        // Return/Enter handled at NSPanel level (DrawerPanel.keyDown) to bypass TextField focus
        .onKeyPress(.space) {
            if let entry = viewModel.filteredEntries[safe: viewModel.selectedIndex] {
                viewModel.quickLookEntry = entry
            }
            return .handled
        }
        .onKeyPress(.delete) {
            if let entry = viewModel.filteredEntries[safe: viewModel.selectedIndex] {
                viewModel.deleteEntry(entry)
            }
            return .handled
        }
        .onAppear {
            viewModel.selectedIndex = 0
            searchFocused = true
        }
        .sheet(isPresented: $viewModel.showPinboardEditor) {
            PinboardEditorView(
                pinboardVM: PinboardViewModel(storage: viewModel.storage),
                existing: viewModel.editingPinboard
            )
            .onDisappear {
                viewModel.editingPinboard = nil
                viewModel.reloadCollections()
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.credentialSaveEntry != nil },
            set: { if !$0 { viewModel.credentialSaveEntry = nil; viewModel.credentialSaveField = nil } }
        )) {
            if let entry = viewModel.credentialSaveEntry,
               let field = viewModel.credentialSaveField,
               let text = entry.textContent {
                CredentialSaveView(
                    clipText: text,
                    field: field,
                    vault: viewModel.vault
                )
            }
        }
    }

    // MARK: - Main content (switches between cards and vault)

    @ViewBuilder
    private var mainContent: some View {
        if case .vault = viewModel.sidebarFilter {
            VaultListView(vault: viewModel.vault, viewModel: viewModel)
        } else {
            CardGridView(viewModel: viewModel)
        }
    }
}

// MARK: - Safe subscript

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
