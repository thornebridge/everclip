import Foundation

struct Credential: Identifiable {
    let id: String
    var platform: String
    var username: String?
    var password: String?
    let createdAt: Date

    /// Create a new credential.
    init(platform: String, username: String? = nil, password: String? = nil) {
        self.id = UUID().uuidString
        self.platform = platform
        self.username = username
        self.password = password
        self.createdAt = Date()
    }

    /// Load from database.
    init(id: String, platform: String, username: String?, password: String?, createdAt: Date) {
        self.id = id
        self.platform = platform
        self.username = username
        self.password = password
        self.createdAt = createdAt
    }

    var maskedPassword: String {
        guard let pw = password, !pw.isEmpty else { return "" }
        return String(repeating: "\u{2022}", count: min(pw.count, 16))
    }

    var displayLabel: String {
        if let u = username, !u.isEmpty { return u }
        if password != nil { return maskedPassword }
        return platform
    }

    static let platformSuggestions = [
        "GitHub", "Gmail", "AWS", "Slack", "Figma", "Notion", "Linear",
        "Vercel", "Cloudflare", "Stripe", "OpenAI", "Discord", "Twitter",
        "Apple ID", "Google", "Microsoft", "Dropbox", "1Password",
        "SSH Key", "API Key", "Database", "Server", "VPN", "WiFi",
    ]
}
