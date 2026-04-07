import SwiftUI

struct PinboardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let storage: StorageManager
    var existing: Pinboard?

    @State private var name: String = ""
    @State private var selectedColor: String = "#3B82F6"

    private let colors = [
        "#3B82F6", "#10B981", "#8B5CF6", "#F59E0B",
        "#EF4444", "#EC4899", "#06B6D4", "#84CC16",
        "#F97316", "#6366F1", "#14B8A6", "#A855F7",
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text(existing == nil ? "New Pinboard" : "Edit Pinboard")
                .font(.system(size: 14, weight: .semibold))

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))

            // Color grid
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 6), count: 6), spacing: 6) {
                ForEach(colors, id: \.self) { hex in
                    Circle()
                        .fill(colorFromHex(hex))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle().strokeBorder(.white.opacity(selectedColor == hex ? 0.8 : 0), lineWidth: 2)
                        )
                        .onTapGesture { selectedColor = hex }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                Spacer()
                Button(existing == nil ? "Create" : "Save") {
                    if var pb = existing {
                        pb.name = name
                        pb.color = selectedColor
                        storage.pinboards.save(pb)
                    } else {
                        let pb = Pinboard(name: name, color: selectedColor)
                        storage.pinboards.save(pb)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 260)
        .onAppear {
            if let pb = existing {
                name = pb.name
                selectedColor = pb.color
            }
        }
    }

    private func colorFromHex(_ hex: String) -> Color { Color(hex: hex) ?? .gray }
}
