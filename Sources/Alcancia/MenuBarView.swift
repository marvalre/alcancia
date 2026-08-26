import SwiftUI
import AlcanciaCore

struct MenuBarView: View {
    @ObservedObject var store: AlcanciaStore
    @State private var showingSettings = false

    private var goalProgress: GoalProgress {
        GoalProgress(totalMXN: store.totalMXN, goalMXN: store.data.goalMXN)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            AddEntryView(store: store)
            Divider()
            HistoryView(store: store)
            Divider()
            footer
        }
        .frame(width: 320, height: 460)
        .sheet(isPresented: $showingSettings) {
            SettingsView(store: store)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.formattedTotal)
                .font(.system(size: 28, weight: .bold, design: .rounded))

            if let goalMXN = store.data.goalMXN, let fraction = goalProgress.fraction {
                ProgressView(value: fraction)
                Text("\(store.formattedTotal) de \(store.formattedAmount(goalMXN))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Sin meta definida")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
    }

    private var footer: some View {
        HStack {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(.borderless)

            Spacer()

            Button("Salir") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
