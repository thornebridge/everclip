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
                    CardGridView(viewModel: viewModel)
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
        .onKeyPress(.return) {
            if let entry = viewModel.filteredEntries[safe: viewModel.selectedIndex] {
                viewModel.select(entry, paste: true)
            }
            return .handled
        }
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
    }
}

// MARK: - Safe subscript

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
