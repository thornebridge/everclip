import SwiftUI

struct FilterBarView: View {
    @ObservedObject var viewModel: DrawerViewModel
    @FocusState.Binding var searchFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12, weight: .medium))
                TextField("Search clipboard…", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($searchFocused)
                if !viewModel.searchText.isEmpty {
                    Button { viewModel.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().frame(height: 16).opacity(0.3)

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(ContentType.allCases, id: \.rawValue) { type in
                        filterChip(type)
                    }
                }
            }

            Spacer()

            // Sidebar toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.isSidebarVisible.toggle()
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 12))
                    .foregroundStyle(viewModel.isSidebarVisible ? .primary : .secondary)
            }
            .buttonStyle(.plain)

            // Hotkey hint
            Text("⌘⇧V")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func filterChip(_ type: ContentType) -> some View {
        let isActive = viewModel.contentTypeFilter == type
        return Button {
            withAnimation(.easeOut(duration: 0.12)) {
                viewModel.contentTypeFilter = isActive ? nil : type
                viewModel.selectedIndex = 0
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: type.iconName)
                    .font(.system(size: 9))
                Text(type.displayName)
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(isActive ? type.accentColor.opacity(0.2) : Color.clear)
            .foregroundStyle(isActive ? type.accentColor : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(isActive ? type.accentColor.opacity(0.4) : Color.gray.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
