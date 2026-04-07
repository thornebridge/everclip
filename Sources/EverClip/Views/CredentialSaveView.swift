import SwiftUI

enum CredentialField {
    case username, password
}

struct CredentialSaveView: View {
    @Environment(\.dismiss) private var dismiss
    let clipText: String
    let field: CredentialField
    let vault: VaultManager

    @State private var platform = ""
    @State private var otherValue = ""
    @State private var platformSearch = ""
    @State private var showSuggestions = false

    private var suggestions: [String] {
        if platformSearch.isEmpty { return Credential.platformSuggestions }
        return Credential.platformSuggestions.filter {
            $0.lowercased().contains(platformSearch.lowercased())
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            header
            Divider().opacity(0.3)
            formContent
            Divider().opacity(0.3)
            actions
        }
        .padding(24)
        .frame(width: 360)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(red: 0, green: 1, blue: 0.529).opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(red: 0, green: 1, blue: 0.529))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Save Credential")
                    .font(.system(size: 15, weight: .bold))
                Text("In-memory only \u{2022} Wiped on quit")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Platform
            VStack(alignment: .leading, spacing: 4) {
                Text("Platform").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                ZStack(alignment: .topLeading) {
                    TextField("e.g. GitHub, Gmail, AWS", text: $platform)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                        .onChange(of: platform) { _, val in
                            platformSearch = val
                            showSuggestions = !val.isEmpty
                        }
                    if showSuggestions && !suggestions.isEmpty && platform.count > 0 {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(suggestions.prefix(5), id: \.self) { s in
                                Button {
                                    platform = s
                                    showSuggestions = false
                                } label: {
                                    Text(s)
                                        .font(.system(size: 12))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 5)
                                        .padding(.horizontal, 8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shadow(color: .black.opacity(0.1), radius: 8)
                        .offset(y: 32)
                        .zIndex(10)
                    }
                }
            }

            // Pre-filled field from clipboard
            VStack(alignment: .leading, spacing: 4) {
                Text(field == .username ? "Username" : "Password")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                HStack {
                    Text(field == .password ? String(repeating: "\u{2022}", count: min(clipText.count, 20)) : clipText)
                        .font(.system(size: 13, design: field == .password ? .monospaced : .default))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "clipboard.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(8)
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Optional other field
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(field == .username ? "Password" : "Username")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    Text("optional")
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }
                if field == .username {
                    SecureField("Enter password", text: $otherValue)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                } else {
                    TextField("Enter username", text: $otherValue)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }
            }
        }
    }

    private var actions: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                saveCredential()
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield")
                    Text("Save to Vault")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0, green: 0.8, blue: 0.42))
            .disabled(platform.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func saveCredential() {
        let username: String?
        let password: String?

        if field == .username {
            username = clipText
            password = otherValue.isEmpty ? nil : otherValue
        } else {
            password = clipText
            username = otherValue.isEmpty ? nil : otherValue
        }

        vault.save(Credential(platform: platform, username: username, password: password))
    }
}
