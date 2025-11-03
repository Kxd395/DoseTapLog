import SwiftUI

extension TodayLogView {
    @ViewBuilder func resetNightEntryPoint(vm: TodayViewModel) -> some View {
        Menu {
            Button(role: .destructive) {
                vm.presentResetNight()
            } label: {
                Label("Reset Night", systemImage: "arrow.clockwise")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    @ViewBuilder func undoResetBanner(vm: TodayViewModel) -> some View {
        if vm.showUndoResetBanner {
            HStack {
                Text("Night reset. Undo?").bold()
                Spacer()
                Button("Undo") { vm.undoResetNight() }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
