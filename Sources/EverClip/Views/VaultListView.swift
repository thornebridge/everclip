import SwiftUI

struct VaultListView: View {
    @ObservedObject var vault: VaultManager
    @ObservedObject var viewModel: DrawerViewModel
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        if vault.credentials.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(vault.platforms, id: \.self) { platform in
                        platformSection(platform)
                    }
                }
                .padding(16)
            }
        }
    }

    private func platformSection(_ platform: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(platform)
                .font(theme.font(size: 12, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.leading, 4)

            ForEach(vault.credentials(forPlatform: platform)) { cred in
                credentialRow(cred)
            }
        }
    }

    private func credentialRow(_ cred: Credential) -> some View {
        HStack(spacing: 12) {
            // Lock icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0, green: 1, blue: 0.529).opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: "lock.fill")
                    .font(theme.font(size: 14))
                    .foregroundStyle(Color(red: 0, green: 1, blue: 0.529))
            }

            // Details
            VStack(alignment: .leading, spacing: 2) {
                if let username = cred.username, !username.isEmpty {
                    Text(username)
                        .font(theme.font(size: 12, weight: .medium))
                        .lineLimit(1)
                }
                if cred.password != nil {
                    Text(cred.maskedPassword)
                        .font(theme.font(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Quick copy buttons
            if cred.username != nil {
                Button {
                    vault.copyUsername(cred, monitor: viewModel.monitor)
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Copy username")
            }

            if cred.password != nil {
                Button {
                    vault.copyPassword(cred, monitor: viewModel.monitor)
                } label: {
                    Image(systemName: "key.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Copy password (clears in 30s)")
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contextMenu {
            if cred.username != nil {
                Button { vault.copyUsername(cred, monitor: viewModel.monitor) } label: {
                    Label("Copy Username", systemImage: "person")
                }
            }
            if cred.password != nil {
                Button { vault.copyPassword(cred, monitor: viewModel.monitor) } label: {
                    Label("Copy Password", systemImage: "key")
                }
            }
            Divider()
            Button(role: .destructive) { vault.delete(id: cred.id) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("Vault is empty")
                .font(theme.font(size: 13))
                .foregroundStyle(.secondary)
            Text("Right-click any clip → Save as Credential")
                .font(theme.font(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
