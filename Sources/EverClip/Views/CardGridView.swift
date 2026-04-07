import SwiftUI

struct CardGridView: View {
    @ObservedObject var viewModel: DrawerViewModel
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        let entries = viewModel.filteredEntries

        if entries.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: theme.dim(10)) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                            cardView(for: entry, at: idx)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .onChange(of: viewModel.selectedIndex) { _, newVal in
                    if let entry = entries[safe: newVal] {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(entry.id, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Card with gestures (separated to avoid type-checker overload)

    private func cardView(for entry: ClipboardEntry, at idx: Int) -> some View {
        ClipboardCardView(entry: entry, isSelected: idx == viewModel.selectedIndex)
            .id(entry.id)
            .onTapGesture(count: 2) { viewModel.select(entry, paste: true) }
            .onTapGesture(count: 1) { viewModel.select(entry, paste: false) }
            .contextMenu { contextMenu(for: entry) }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenu(for entry: ClipboardEntry) -> some View {
        Button { viewModel.select(entry, paste: false) } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        Button { viewModel.select(entry, paste: true) } label: {
            Label("Paste", systemImage: "doc.on.clipboard")
        }

        if entry.textContent != nil {
            Menu("Paste as…") {
                ForEach(PasteTransformation.allCases) { transform in
                    Button(transform.displayName) {
                        viewModel.selectTransformed(entry, transform: transform)
                    }
                }
            }
        }

        Divider()

        if !viewModel.pinboards.isEmpty {
            Menu("Pin to Pinboard") {
                ForEach(viewModel.pinboards) { pb in
                    let pinned = viewModel.isPinned(entryID: entry.id, pinboardID: pb.id)
                    Button {
                        viewModel.togglePinboard(entryID: entry.id, pinboardID: pb.id)
                    } label: {
                        HStack {
                            Text(pb.name)
                            if pinned { Image(systemName: "checkmark") }
                        }
                    }
                }
            }
        }

        if !viewModel.tags.isEmpty {
            Menu("Tag") {
                ForEach(viewModel.tags) { tag in
                    let tagged = viewModel.hasTag(entryID: entry.id, tagID: tag.id)
                    Button {
                        viewModel.toggleTag(entryID: entry.id, tagID: tag.id)
                    } label: {
                        HStack {
                            Text(tag.name)
                            if tagged { Image(systemName: "checkmark") }
                        }
                    }
                }
            }
        }

        Divider()

        Button {
            viewModel.toggleFavorite(entry)
        } label: {
            Label(entry.isFavorite ? "Unfavorite" : "Favorite",
                  systemImage: entry.isFavorite ? "star.slash" : "star")
        }

        Button {
            viewModel.quickLookEntry = entry
        } label: {
            Label("Quick Look", systemImage: "eye")
        }

        Divider()

        Button(role: .destructive) {
            viewModel.deleteEntry(entry)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "clipboard")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text(viewModel.monitor.entries.isEmpty ? "Clipboard history is empty" : "No matches")
                .font(theme.font(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
