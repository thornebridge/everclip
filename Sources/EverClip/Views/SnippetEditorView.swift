import SwiftUI

struct SnippetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let storage: StorageManager
    var existing: Snippet?
    var onSave: () -> Void

    @State private var abbreviation = ""
    @State private var expansionText = ""

    var body: some View {
        VStack(spacing: 16) {
            Text(existing == nil ? "New Snippet" : "Edit Snippet")
                .font(.system(size: 14, weight: .semibold))

            Form {
                Section("Trigger") {
                    TextField("Abbreviation (e.g. ;email)", text: $abbreviation)
                        .font(.system(.body, design: .monospaced))
                }

                Section("Expansion") {
                    TextEditor(text: $expansionText)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                        .padding(4)
                        .background(Color.black.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Section("Template Variables") {
                    HStack(spacing: 6) {
                        templateButton("{{date}}", "Current date")
                        templateButton("{{time}}", "Current time")
                        templateButton("{{iso}}", "ISO date")
                        templateButton("{{clipboard}}", "Clipboard")
                    }
                }

                if !expansionText.isEmpty {
                    Section("Preview") {
                        let preview = Snippet(abbreviation: abbreviation, expansionText: expansionText).expand()
                        Text(preview)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.plain)
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(abbreviation.trimmingCharacters(in: .whitespaces).isEmpty
                              || expansionText.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 420, height: 480)
        .onAppear {
            if let s = existing {
                abbreviation = s.abbreviation
                expansionText = s.expansionText
            }
        }
    }

    private func templateButton(_ variable: String, _ tooltip: String) -> some View {
        Button {
            expansionText += variable
        } label: {
            Text(variable)
                .font(.system(size: 10, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    private func save() {
        let snippet: Snippet
        if var s = existing {
            s.abbreviation = abbreviation
            s.expansionText = expansionText
            snippet = s
        } else {
            snippet = Snippet(abbreviation: abbreviation, expansionText: expansionText)
        }
        storage.snippets.save(snippet)
        onSave()
        dismiss()
    }
}
