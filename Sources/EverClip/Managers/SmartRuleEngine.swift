import Foundation

struct SmartRuleEngine {
    /// Evaluates all enabled rules against an entry. Returns pinboard IDs to assign.
    /// AND logic within each rule, OR logic across rules.
    static func evaluate(entry: ClipboardEntry, rules: [SmartRule]) -> [String] {
        var pinboardIDs: [String] = []

        for rule in rules where rule.isEnabled {
            guard let targetID = rule.targetPinboardID else { continue }
            let allMatch = rule.conditions.allSatisfy { condition in
                matches(condition: condition, entry: entry)
            }
            if allMatch && !rule.conditions.isEmpty {
                pinboardIDs.append(targetID)
            }
        }

        return pinboardIDs
    }

    private static func matches(condition: RuleCondition, entry: ClipboardEntry) -> Bool {
        switch condition {
        case .sourceApp(let bundleID):
            return entry.sourceAppBundleID == bundleID

        case .contentType(let type):
            return entry.contentType == type

        case .textMatches(let pattern):
            guard let text = entry.textContent else { return false }
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return false }
            let range = NSRange(text.startIndex..., in: text)
            return regex.firstMatch(in: text, range: range) != nil

        case .urlDomain(let domain):
            guard let text = entry.textContent, let url = URL(string: text), let host = url.host else { return false }
            return host.lowercased().contains(domain.lowercased())
        }
    }
}
