import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: DrawerViewModel
    @State private var newTagName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            filterRow("tray.full", "All Items", count: viewModel.allItemsCount(), filter: .all)
            filterRow("star", "Favorites", count: viewModel.favoriteCount(), filter: .favorites)

            // PINBOARDS
            HStack {
                sectionHeader("PINBOARDS")
                Spacer()
                Button { viewModel.showPinboardEditor = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)

            ForEach(viewModel.pinboards) { pb in
                pinboardRow(pb)
            }

            // TAGS
            HStack {
                sectionHeader("TAGS")
                Spacer()
                Button { viewModel.showNewTagField.toggle() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)

            if viewModel.showNewTagField {
                HStack(spacing: 4) {
                    TextField("Tag name", text: $newTagName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .onSubmit {
                            let name = newTagName.trimmingCharacters(in: .whitespaces)
                            if !name.isEmpty {
                                viewModel.createTag(name: name)
                                newTagName = ""
                                viewModel.showNewTagField = false
                            }
                        }
                    Button {
                        viewModel.showNewTagField = false
                        newTagName = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
            }

            ForEach(viewModel.tags) { tag in
                tagRow(tag)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
    }

    // MARK: - Filter row

    private func filterRow(_ icon: String, _ title: String, count: Int, filter: SidebarFilter) -> some View {
        let isSelected = viewModel.sidebarFilter == filter
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                viewModel.sidebarFilter = filter
                viewModel.selectedIndex = 0
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor.opacity(0.15) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pinboard row

    private func pinboardRow(_ pb: Pinboard) -> some View {
        let isSelected = viewModel.sidebarFilter == .pinboard(id: pb.id)
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                viewModel.sidebarFilter = .pinboard(id: pb.id)
                viewModel.selectedIndex = 0
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(colorFromHex(pb.color))
                    .frame(width: 8, height: 8)
                Text(pb.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer()
                Text("\(viewModel.pinboardEntryCount(pb.id))")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor.opacity(0.15) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Rename…") {
                viewModel.editingPinboard = pb
                viewModel.showPinboardEditor = true
            }
            Divider()
            Button("Delete", role: .destructive) {
                viewModel.deletePinboard(pb.id)
            }
        }
    }

    // MARK: - Tag row

    private func tagRow(_ tag: Tag) -> some View {
        let isSelected = viewModel.sidebarFilter == .tag(id: tag.id)
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                viewModel.sidebarFilter = .tag(id: tag.id)
                viewModel.selectedIndex = 0
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "tag")
                    .font(.system(size: 10))
                    .foregroundStyle(colorFromHex(tag.color))
                    .frame(width: 16)
                Text(tag.name)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer()
                Text("\(viewModel.tagEntryCount(tag.id))")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor.opacity(0.15) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete", role: .destructive) {
                viewModel.deleteTag(tag.id)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.tertiary)
    }

    private func colorFromHex(_ hex: String) -> Color {
        let stripped = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard let val = UInt64(stripped, radix: 16) else { return .gray }
        return Color(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >> 8) & 0xFF) / 255,
            blue:  Double(val & 0xFF) / 255
        )
    }
}
