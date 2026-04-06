import SwiftUI

struct PreferencesView: View {
    let storage: StorageManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralTab(storage: storage).tabItem { Label("General", systemImage: "gearshape") }.tag(0)
            PrivacyTab(storage: storage).tabItem { Label("Privacy", systemImage: "lock.shield") }.tag(1)
            RulesTab(storage: storage).tabItem { Label("Rules", systemImage: "bolt") }.tag(2)
            SnippetsTab(storage: storage).tabItem { Label("Snippets", systemImage: "text.cursor") }.tag(3)
        }
        .frame(width: 520, height: 420)
    }
}

// MARK: - General

private struct GeneralTab: View {
    let storage: StorageManager
    @State private var maxEntries: Double = 1000
    @State private var retentionIndex = 4 // 1 year

    private let retentionOptions = [
        ("1 Day", 1), ("1 Week", 7), ("1 Month", 30),
        ("3 Months", 90), ("1 Year", 365), ("Forever", 0)
    ]

    var body: some View {
        Form {
            Section("History") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Maximum Items: \(Int(maxEntries))")
                    Slider(value: $maxEntries, in: 100...10000, step: 100)
                        .onChange(of: maxEntries) { _, val in
                            storage.preferences.setInt("maxEntries", value: Int(val))
                        }
                }

                Picker("Retention Period", selection: $retentionIndex) {
                    ForEach(0..<retentionOptions.count, id: \.self) { idx in
                        Text(retentionOptions[idx].0).tag(idx)
                    }
                }
                .onChange(of: retentionIndex) { _, idx in
                    storage.preferences.setInt("retentionDays", value: retentionOptions[idx].1)
                }
            }

            Section("Shortcuts") {
                HStack {
                    Text("Show Clipboard History")
                    Spacer()
                    Text("⌘⇧V").font(.system(.body, design: .rounded)).foregroundStyle(.secondary)
                }
                HStack {
                    Text("Paste Stack")
                    Spacer()
                    Text("⌘⇧C").font(.system(.body, design: .rounded)).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            maxEntries = Double(storage.preferences.getInt("maxEntries", default: 1000))
            let days = storage.preferences.getInt("retentionDays", default: 365)
            retentionIndex = retentionOptions.firstIndex(where: { $0.1 == days }) ?? 4
        }
    }
}

// MARK: - Privacy

private struct PrivacyTab: View {
    let storage: StorageManager
    @State private var excludedIDs: [String] = []
    @State private var manualBundleID = ""
    @State private var runningApps: [(String, String)] = [] // (name, bundleID)

    var body: some View {
        Form {
            Section("Excluded Apps") {
                Text("Clipboard captures from these apps will be ignored.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if excludedIDs.isEmpty {
                    Text("No apps excluded")
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    ForEach(excludedIDs, id: \.self) { bundleID in
                        HStack {
                            Text(bundleID)
                                .font(.system(size: 12, design: .monospaced))
                            Spacer()
                            Button { removeExclusion(bundleID) } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Section("Add Exclusion") {
                Menu("Add Running App") {
                    ForEach(runningApps, id: \.1) { name, bundleID in
                        Button("\(name) — \(bundleID)") {
                            addExclusion(bundleID)
                        }
                    }
                }

                HStack {
                    TextField("Bundle ID (e.g. com.1password.1password)", text: $manualBundleID)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                    Button("Add") {
                        let id = manualBundleID.trimmingCharacters(in: .whitespaces)
                        if !id.isEmpty { addExclusion(id); manualBundleID = "" }
                    }
                    .disabled(manualBundleID.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            excludedIDs = storage.preferences.getStringArray("excludedBundleIDs")
            runningApps = NSWorkspace.shared.runningApplications
                .compactMap { app in
                    guard let name = app.localizedName, let bid = app.bundleIdentifier else { return nil }
                    return (name, bid)
                }
                .sorted { $0.0 < $1.0 }
        }
    }

    private func addExclusion(_ bundleID: String) {
        guard !excludedIDs.contains(bundleID) else { return }
        excludedIDs.append(bundleID)
        storage.preferences.setStringArray("excludedBundleIDs", value: excludedIDs)
    }

    private func removeExclusion(_ bundleID: String) {
        excludedIDs.removeAll { $0 == bundleID }
        storage.preferences.setStringArray("excludedBundleIDs", value: excludedIDs)
    }
}

// MARK: - Rules

private struct RulesTab: View {
    let storage: StorageManager
    @State private var rules: [SmartRule] = []
    @State private var showEditor = false
    @State private var editingRule: SmartRule?

    var body: some View {
        VStack(spacing: 0) {
            if rules.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bolt.slash")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("No smart rules yet")
                        .foregroundStyle(.secondary)
                    Text("Rules auto-assign clipboard entries to pinboards based on conditions.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(rules) { rule in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.name).font(.system(size: 13, weight: .medium))
                                Text(ruleSummary(rule))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { rule.isEnabled },
                                set: { newVal in
                                    var r = rule; r.isEnabled = newVal
                                    storage.smartRules.save(r)
                                    reload()
                                }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        }
                        .contextMenu {
                            Button("Edit…") { editingRule = rule; showEditor = true }
                            Button("Delete", role: .destructive) {
                                storage.smartRules.delete(id: rule.id); reload()
                            }
                        }
                    }
                }
            }

            Divider()
            HStack {
                Spacer()
                Button { editingRule = nil; showEditor = true } label: {
                    Label("New Rule", systemImage: "plus")
                }
                .padding(10)
            }
        }
        .sheet(isPresented: $showEditor) {
            SmartRuleEditorView(storage: storage, existing: editingRule) { reload() }
        }
        .onAppear { reload() }
    }

    private func reload() { rules = storage.smartRules.loadAll() }

    private func ruleSummary(_ rule: SmartRule) -> String {
        let parts = rule.conditions.map { cond in
            switch cond {
            case .sourceApp(let id): "app: \(id.components(separatedBy: ".").last ?? id)"
            case .contentType(let t): "type: \(t.displayName)"
            case .textMatches(let p): "matches: \(p)"
            case .urlDomain(let d):   "domain: \(d)"
            }
        }
        return parts.joined(separator: " + ")
    }
}

// MARK: - Snippets

private struct SnippetsTab: View {
    let storage: StorageManager
    @State private var snippets: [Snippet] = []
    @State private var showEditor = false
    @State private var editingSnippet: Snippet?

    var body: some View {
        VStack(spacing: 0) {
            if snippets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.cursor")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("No snippets yet")
                        .foregroundStyle(.secondary)
                    Text("Snippets let you save frequently used text with template variables like {{date}}.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(snippets) { snippet in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(snippet.abbreviation)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                Text(snippet.expansionText)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Text("×\(snippet.useCount)")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(.tertiary)
                        }
                        .contextMenu {
                            Button("Edit…") { editingSnippet = snippet; showEditor = true }
                            Button("Delete", role: .destructive) {
                                storage.snippets.delete(id: snippet.id); reload()
                            }
                        }
                    }
                }
            }

            Divider()
            HStack {
                Spacer()
                Button { editingSnippet = nil; showEditor = true } label: {
                    Label("New Snippet", systemImage: "plus")
                }
                .padding(10)
            }
        }
        .sheet(isPresented: $showEditor) {
            SnippetEditorView(storage: storage, existing: editingSnippet) { reload() }
        }
        .onAppear { reload() }
    }

    private func reload() { snippets = storage.snippets.loadAll() }
}
