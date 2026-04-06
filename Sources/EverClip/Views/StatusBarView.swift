import SwiftUI

struct StatusBarView: View {
    @ObservedObject var viewModel: DrawerViewModel

    var body: some View {
        HStack(spacing: 8) {
            Text("\(viewModel.filteredEntries.count) items")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            Spacer()

            if viewModel.monitor.isPaused {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                    Text("Paused")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.orange)
                }
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("Active")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }
}
