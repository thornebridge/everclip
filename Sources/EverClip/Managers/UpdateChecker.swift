import Foundation
import AppKit

final class UpdateChecker: ObservableObject {
    @Published var updateAvailable = false
    @Published var latestVersion: String?
    @Published var releaseURL: String?
    @Published var releaseNotes: String?

    private let currentVersion = "2.2.0"
    private let versionURL = "https://thornebridge.github.io/everclip/version.json"
    private let checkIntervalSeconds: TimeInterval = 6 * 3600 // 6 hours

    func checkIfNeeded() {
        let lastCheck = UserDefaults.standard.double(forKey: "lastUpdateCheck")
        let now = Date().timeIntervalSince1970
        if now - lastCheck < checkIntervalSeconds { return }
        check()
    }

    func check() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastUpdateCheck")

        guard let url = URL(string: versionURL) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self, let data, error == nil else { return }
            guard let info = try? JSONDecoder().decode(VersionInfo.self, from: data) else { return }

            DispatchQueue.main.async {
                if self.isNewer(info.latest, than: self.currentVersion) {
                    self.updateAvailable = true
                    self.latestVersion = info.latest
                    self.releaseURL = info.url
                    self.releaseNotes = info.notes
                }
            }
        }.resume()
    }

    func openReleasePage() {
        let urlString = releaseURL ?? "https://github.com/thornebridge/everclip/releases/latest"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    func dismiss() {
        updateAvailable = false
    }

    private func isNewer(_ remote: String, than local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }
}

private struct VersionInfo: Codable {
    let latest: String
    let url: String
    let notes: String?
}
