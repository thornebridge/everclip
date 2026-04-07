import SwiftUI
import AppKit

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var displayName: String {
        switch self { case .system: "System"; case .light: "Light"; case .dark: "Dark" }
    }
}

enum CardSize: String, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }
    var displayName: String {
        switch self { case .small: "Compact"; case .medium: "Default"; case .large: "Large" }
    }
    var width: CGFloat { switch self { case .small: 160; case .medium: 190; case .large: 230 } }
    var height: CGFloat { switch self { case .small: 130; case .medium: 160; case .large: 200 } }
}

enum DrawerMaterial: String, CaseIterable, Identifiable {
    case hudWindow, sidebar, underWindow, menu, popover, titlebar
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .hudWindow: "HUD (Default)"
        case .sidebar: "Sidebar"
        case .underWindow: "Under Window"
        case .menu: "Menu"
        case .popover: "Popover"
        case .titlebar: "Title Bar"
        }
    }
    var nsMaterial: NSVisualEffectView.Material {
        switch self {
        case .hudWindow: .hudWindow
        case .sidebar: .sidebar
        case .underWindow: .underWindowBackground
        case .menu: .menu
        case .popover: .popover
        case .titlebar: .titlebar
        }
    }
}

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    // MARK: - Published tokens

    @Published var appearance: AppearanceMode = .system { didSet { applyAppearance(); save("appearance", appearance.rawValue) } }
    @Published var accentHex: String = "#00ff87" { didSet { save("accentHex", accentHex) } }
    @Published var uiScale: CGFloat = 1.0 { didSet { save("uiScale", "\(Double(uiScale))") } }
    @Published var fontScale: CGFloat = 1.0 { didSet { save("fontScale", "\(Double(fontScale))") } }
    @Published var cardSize: CardSize = .medium { didSet { save("cardSize", cardSize.rawValue) } }
    @Published var drawerMaterial: DrawerMaterial = .hudWindow { didSet { save("drawerMaterial", drawerMaterial.rawValue) } }
    @Published var drawerCornerRadius: CGFloat = 16 { didSet { save("drawerCornerRadius", "\(Double(drawerCornerRadius))") } }

    var onMaterialChange: (() -> Void)?

    // MARK: - Derived

    var accentColor: Color {
        colorFromHex(accentHex) ?? .green
    }

    // MARK: - Scaling helpers

    func font(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(size: size * fontScale, weight: weight, design: design)
    }

    func dim(_ value: CGFloat) -> CGFloat {
        (value * uiScale).rounded()
    }

    // MARK: - Preset accent colors

    static let accentPresets: [(String, String)] = [
        ("#00ff87", "Green"),
        ("#3b82f6", "Blue"),
        ("#8b5cf6", "Purple"),
        ("#f59e0b", "Amber"),
        ("#f43f5e", "Rose"),
        ("#06b6d4", "Cyan"),
        ("#ec4899", "Pink"),
        ("#ef4444", "Red"),
        ("#ffffff", "White"),
    ]

    // MARK: - Init

    private var store: PreferencesStore?

    private init() {}

    func load(from store: PreferencesStore) {
        self.store = store
        appearance = AppearanceMode(rawValue: store.get("appearance") ?? "system") ?? .system
        accentHex = store.get("accentHex") ?? "#00ff87"
        uiScale = Double(store.get("uiScale") ?? "1.0") ?? 1.0
        fontScale = Double(store.get("fontScale") ?? "1.0") ?? 1.0
        cardSize = CardSize(rawValue: store.get("cardSize") ?? "medium") ?? .medium
        drawerMaterial = DrawerMaterial(rawValue: store.get("drawerMaterial") ?? "hudWindow") ?? .hudWindow
        drawerCornerRadius = Double(store.get("drawerCornerRadius") ?? "16") ?? 16
        applyAppearance()
    }

    // MARK: - Private

    private func save(_ key: String, _ value: String) {
        store?.set("theme.\(key)", value: value)
        if key == "drawerMaterial" || key == "drawerCornerRadius" {
            DispatchQueue.main.async { self.onMaterialChange?() }
        }
    }

    private func applyAppearance() {
        switch appearance {
        case .system: NSApp.appearance = nil
        case .light:  NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:   NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func colorFromHex(_ hex: String) -> Color? {
        let stripped = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard stripped.count == 6, let val = UInt64(stripped, radix: 16) else { return nil }
        return Color(
            red: Double((val >> 16) & 0xFF) / 255,
            green: Double((val >> 8) & 0xFF) / 255,
            blue: Double(val & 0xFF) / 255
        )
    }
}
