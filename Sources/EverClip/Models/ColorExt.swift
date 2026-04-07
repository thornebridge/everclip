import SwiftUI

extension Color {
    init?(hex: String) {
        let stripped = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let expanded: String
        if stripped.count == 3 {
            expanded = stripped.map { "\($0)\($0)" }.joined()
        } else if stripped.count == 6 {
            expanded = stripped
        } else {
            return nil
        }
        guard expanded.allSatisfy({ $0.isHexDigit }),
              let val = UInt64(expanded, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >> 8) & 0xFF) / 255,
            blue:  Double(val & 0xFF) / 255
        )
    }
}
