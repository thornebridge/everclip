import SwiftUI

struct ClipboardCardView: View {
    let entry: ClipboardEntry
    let isSelected: Bool
    @EnvironmentObject private var theme: ThemeManager

    @State private var thumbnail: NSImage?
    @State private var isHovering = false

    private var accent: Color { entry.contentType.accentColor }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.dim(6)) {
            header
            Divider().opacity(0.2)
            preview
            Spacer(minLength: 0)
            footer
        }
        .padding(theme.dim(10))
        .frame(width: theme.cardSize.width * theme.uiScale, height: theme.cardSize.height * theme.uiScale)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: theme.dim(12)))
        .overlay(
            RoundedRectangle(cornerRadius: theme.dim(12))
                .strokeBorder(
                    accent.opacity(isSelected ? 1 : (isHovering ? 0.7 : 0.45)),
                    lineWidth: isSelected ? 2.5 : 1.5
                )
        )
        .shadow(color: isSelected ? accent.opacity(0.25) : .clear, radius: 8, y: 2)
        .scaleEffect(isHovering ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .onHover { isHovering = $0 }
        .onAppear { loadThumbnail() }
        .help(entry.textContent ?? entry.contentType.displayName)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: entry.contentType.iconName)
                .font(theme.font(size: 10, weight: .semibold))
            Text(entry.contentType.displayName)
                .font(theme.font(size: 10, weight: .semibold))
            Spacer()
            if entry.isFavorite {
                Image(systemName: "star.fill")
                    .font(theme.font(size: 8))
                    .foregroundStyle(.yellow)
            }
        }
        .foregroundColor(accent)
    }

    // MARK: - Preview (all fonts use theme scaling)

    @ViewBuilder
    private var preview: some View {
        switch entry.contentType {
        case .image:    imagePreview
        case .url:      urlPreview
        case .code:     codePreview
        case .color:    colorPreview
        case .markdown: markdownPreview
        default:        textPreview
        }
    }

    private var imagePreview: some View {
        Group {
            if let img = thumbnail {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: theme.dim(6)))
            } else {
                RoundedRectangle(cornerRadius: theme.dim(6))
                    .fill(.quaternary)
                    .overlay(Image(systemName: "photo").foregroundStyle(.tertiary))
            }
        }
        .frame(maxHeight: theme.dim(80))
    }

    private var urlPreview: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let text = entry.textContent, let host = URL(string: text)?.host {
                Text(host)
                    .font(theme.font(size: 10, weight: .medium))
                    .foregroundStyle(accent)
            }
            Text(entry.displayText)
                .font(theme.font(size: 10))
                .foregroundStyle(.primary.opacity(0.8))
                .lineLimit(4)
        }
    }

    private var codePreview: some View {
        Text(entry.displayText)
            .font(theme.font(size: 9, design: .monospaced))
            .foregroundStyle(.primary.opacity(0.85))
            .lineLimit(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(theme.dim(6))
            .background(Color.black.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: theme.dim(6)))
    }

    private var colorPreview: some View {
        HStack(spacing: 8) {
            if let color = parseColor(entry.textContent ?? "") {
                RoundedRectangle(cornerRadius: theme.dim(6))
                    .fill(color)
                    .frame(width: theme.dim(36), height: theme.dim(36))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.dim(6))
                            .strokeBorder(.primary.opacity(0.15), lineWidth: 1)
                    )
            }
            Text(entry.displayText)
                .font(theme.font(size: 10, design: .monospaced))
                .lineLimit(2)
        }
    }

    private var markdownPreview: some View {
        MarkdownPreviewView(markdown: entry.displayText)
            .frame(maxWidth: .infinity, maxHeight: theme.dim(80))
            .clipShape(RoundedRectangle(cornerRadius: theme.dim(6)))
    }

    private var textPreview: some View {
        Text(entry.displayText)
            .font(theme.font(size: 11))
            .foregroundStyle(.primary.opacity(0.85))
            .lineLimit(5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if let app = entry.sourceApp {
                HStack(spacing: 3) {
                    if let bundleID = entry.sourceAppBundleID,
                       let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: theme.dim(12), height: theme.dim(12))
                    }
                    Text(app)
                        .font(theme.font(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(entry.createdAt, style: .relative)
                .font(theme.font(size: 9))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Helpers

    private func loadThumbnail() {
        guard entry.contentType == .image, let path = entry.imagePath, thumbnail == nil else { return }
        thumbnail = NSImage(contentsOfFile: path)
    }

    private func parseColor(_ text: String) -> Color? {
        let hex = text.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6 || hex.count == 3, hex.allSatisfy({ $0.isHexDigit }) else { return nil }
        let expanded = hex.count == 3 ? hex.map { "\($0)\($0)" }.joined() : hex
        guard let val = UInt64(expanded, radix: 16) else { return nil }
        return Color(red: Double((val >> 16) & 0xFF) / 255, green: Double((val >> 8) & 0xFF) / 255, blue: Double(val & 0xFF) / 255)
    }
}
