import SwiftUI

struct QuickLookPreviewView: View {
    let entry: ClipboardEntry
    let onDismiss: () -> Void

    @State private var fullImage: NSImage?

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: entry.contentType.iconName)
                        .foregroundStyle(entry.contentType.accentColor)
                    Text(entry.effectiveTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    if let app = entry.sourceApp {
                        Text(app)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.createdAt, style: .relative)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Button { onDismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)

                Divider().opacity(0.3)

                // Content
                ScrollView {
                    previewContent
                        .padding(14)
                }
            }
            .frame(maxWidth: 600, maxHeight: 420)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        }
        .focusable()
        .onKeyPress(.escape) { onDismiss(); return .handled }
        .onKeyPress(.space)  { onDismiss(); return .handled }
        .onAppear { loadImage() }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch entry.contentType {
        case .image:
            if let img = fullImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        case .code:
            ScrollView(.horizontal, showsIndicators: true) {
                Text(entry.textContent ?? "")
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(Color.black.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        case .url:
            VStack(alignment: .leading, spacing: 8) {
                if let text = entry.textContent {
                    Link(destination: URL(string: text) ?? URL(string: "about:blank")!) {
                        Text(text)
                            .font(.system(size: 13))
                            .foregroundStyle(.blue)
                    }
                }
            }
        case .markdown:
            if let text = entry.textContent {
                MarkdownPreviewView(markdown: text)
                    .frame(minHeight: 200)
            }
        case .color:
            if let text = entry.textContent {
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(parseColor(text) ?? .gray)
                        .frame(width: 80, height: 80)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.primary.opacity(0.15)))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(text)
                            .font(.system(size: 16, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
        default:
            Text(entry.textContent ?? "")
                .font(.system(size: 13))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func loadImage() {
        if let path = entry.imagePath { fullImage = NSImage(contentsOfFile: path) }
    }

    private func parseColor(_ text: String) -> Color? {
        let hex = text.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard (hex.count == 3 || hex.count == 6), hex.allSatisfy({ $0.isHexDigit }) else { return nil }
        let expanded = hex.count == 3 ? hex.map { "\($0)\($0)" }.joined() : hex
        guard let val = UInt64(expanded, radix: 16) else { return nil }
        return Color(red: Double((val >> 16) & 0xFF) / 255, green: Double((val >> 8) & 0xFF) / 255, blue: Double(val & 0xFF) / 255)
    }
}
