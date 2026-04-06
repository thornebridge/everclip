import SwiftUI

struct SmartRuleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let storage: StorageManager
    var existing: SmartRule?
    var onSave: () -> Void

    @State private var name = ""
    @State private var targetPinboardID: String?
    @State private var conditions: [RuleCondition] = []
    @State private var isEnabled = true

    private var pinboards: [Pinboard] { storage.pinboards.loadAll() }

    var body: some View {
        VStack(spacing: 16) {
            Text(existing == nil ? "New Smart Rule" : "Edit Rule")
                .font(.system(size: 14, weight: .semibold))

            Form {
                TextField("Rule Name", text: $name)

                Picker("Target Pinboard", selection: $targetPinboardID) {
                    Text("None").tag(String?.none)
                    ForEach(pinboards) { pb in
                        Text(pb.name).tag(Optional(pb.id))
                    }
                }

                Section("Conditions (all must match)") {
                    ForEach(Array(conditions.enumerated()), id: \.offset) { idx, condition in
                        conditionRow(idx: idx, condition: condition)
                    }

                    Button { conditions.append(.contentType(.text)) } label: {
                        Label("Add Condition", systemImage: "plus")
                    }
                }

                Toggle("Enabled", isOn: $isEnabled)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 420, height: 460)
        .onAppear {
            if let r = existing {
                name = r.name
                targetPinboardID = r.targetPinboardID
                conditions = r.conditions
                isEnabled = r.isEnabled
            }
        }
    }

    @ViewBuilder
    private func conditionRow(idx: Int, condition: RuleCondition) -> some View {
        HStack {
            conditionEditor(idx: idx, condition: condition)
            Button { conditions.remove(at: idx) } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func conditionEditor(idx: Int, condition: RuleCondition) -> some View {
        let typeBinding = Binding<String>(
            get: {
                switch condition {
                case .sourceApp:   return "sourceApp"
                case .contentType: return "contentType"
                case .textMatches: return "textMatches"
                case .urlDomain:   return "urlDomain"
                }
            },
            set: { newType in
                switch newType {
                case "sourceApp":   conditions[idx] = .sourceApp(bundleID: "")
                case "contentType": conditions[idx] = .contentType(.text)
                case "textMatches": conditions[idx] = .textMatches(pattern: "")
                case "urlDomain":   conditions[idx] = .urlDomain("")
                default: break
                }
            }
        )

        Picker("", selection: typeBinding) {
            Text("Source App").tag("sourceApp")
            Text("Content Type").tag("contentType")
            Text("Text Matches").tag("textMatches")
            Text("URL Domain").tag("urlDomain")
        }
        .frame(width: 120)

        switch condition {
        case .sourceApp(let bundleID):
            TextField("Bundle ID", text: Binding(
                get: { bundleID },
                set: { conditions[idx] = .sourceApp(bundleID: $0) }
            ))
        case .contentType(let type):
            Picker("", selection: Binding(
                get: { type },
                set: { conditions[idx] = .contentType($0) }
            )) {
                ForEach(ContentType.allCases, id: \.rawValue) { t in
                    Text(t.displayName).tag(t)
                }
            }
        case .textMatches(let pattern):
            TextField("Regex pattern", text: Binding(
                get: { pattern },
                set: { conditions[idx] = .textMatches(pattern: $0) }
            ))
        case .urlDomain(let domain):
            TextField("Domain", text: Binding(
                get: { domain },
                set: { conditions[idx] = .urlDomain($0) }
            ))
        }
    }

    private func save() {
        let rule: SmartRule
        if var r = existing {
            r.name = name
            r.targetPinboardID = targetPinboardID
            r.conditions = conditions
            r.isEnabled = isEnabled
            rule = r
        } else {
            rule = SmartRule(name: name, targetPinboardID: targetPinboardID,
                           conditions: conditions, isEnabled: isEnabled)
        }
        storage.smartRules.save(rule)
        onSave()
        dismiss()
    }
}
