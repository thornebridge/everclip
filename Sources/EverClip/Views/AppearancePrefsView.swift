import SwiftUI

struct AppearancePrefsView: View {
    @ObservedObject var theme = ThemeManager.shared
    @State private var customHex = ""

    var body: some View {
        Form {
            themeSection
            accentSection
            scaleSection
            cardSection
            drawerSection
            resetSection
        }
        .formStyle(.grouped)
        .onAppear { customHex = theme.accentHex }
    }

    // MARK: - Sections

    private var themeSection: some View {
        Section("Theme") {
            Picker("Appearance", selection: $theme.appearance) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var accentSection: some View {
        Section("Accent Color") {
            accentColorGrid
            customHexField
        }
    }

    private var accentColorGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(36), spacing: 8), count: 9), spacing: 8) {
            ForEach(ThemeManager.accentPresets, id: \.0) { hex, name in
                accentSwatch(hex: hex, name: name)
            }
        }
    }

    private func accentSwatch(hex: String, name: String) -> some View {
        let isSelected = theme.accentHex.lowercased() == hex.lowercased()
        return Button {
            theme.accentHex = hex
            customHex = hex
        } label: {
            ZStack {
                Circle().fill(colorFromHex(hex) ?? .gray).frame(width: 28, height: 28)
                if hex == "#ffffff" {
                    Circle().strokeBorder(Color.gray.opacity(0.3), lineWidth: 1).frame(width: 28, height: 28)
                }
                if isSelected {
                    Circle().strokeBorder(Color.primary, lineWidth: 2.5).frame(width: 34, height: 34)
                }
            }
        }
        .buttonStyle(.plain)
        .help(name)
    }

    private var customHexField: some View {
        HStack {
            Text("Custom").font(.system(size: 12)).foregroundStyle(.secondary)
            TextField("#hex", text: $customHex)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 100)
                .onSubmit {
                    let hex = customHex.hasPrefix("#") ? customHex : "#\(customHex)"
                    if hex.count == 7 { theme.accentHex = hex }
                }
            Circle()
                .fill(colorFromHex(customHex.hasPrefix("#") ? customHex : "#\(customHex)") ?? .gray)
                .frame(width: 16, height: 16)
        }
    }

    private var scaleSection: some View {
        Section("Scale") {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("UI Scale"); Spacer()
                    Text("\(Int(theme.uiScale * 100))%")
                        .font(.system(size: 12, design: .rounded)).foregroundStyle(.secondary)
                }
                Slider(value: $theme.uiScale, in: 0.75...1.4, step: 0.05)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Font Scale"); Spacer()
                    Text("\(Int(theme.fontScale * 100))%")
                        .font(.system(size: 12, design: .rounded)).foregroundStyle(.secondary)
                }
                Slider(value: $theme.fontScale, in: 0.75...1.4, step: 0.05)
            }
        }
    }

    private var cardSection: some View {
        Section("Cards") {
            Picker("Card Size", selection: $theme.cardSize) {
                ForEach(CardSize.allCases) { size in
                    Text(size.displayName).tag(size)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var drawerSection: some View {
        Section("Drawer") {
            Picker("Material", selection: $theme.drawerMaterial) {
                ForEach(DrawerMaterial.allCases) { mat in
                    Text(mat.displayName).tag(mat)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Corner Radius"); Spacer()
                    Text("\(Int(theme.drawerCornerRadius))px")
                        .font(.system(size: 12, design: .rounded)).foregroundStyle(.secondary)
                }
                Slider(value: $theme.drawerCornerRadius, in: 0...32, step: 2)
            }
        }
    }

    private var resetSection: some View {
        Section {
            Button("Reset to Defaults") {
                theme.appearance = .system
                theme.accentHex = "#00ff87"
                theme.uiScale = 1.0
                theme.fontScale = 1.0
                theme.cardSize = .medium
                theme.drawerMaterial = .hudWindow
                theme.drawerCornerRadius = 16
                customHex = "#00ff87"
            }
            .foregroundStyle(.red)
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
