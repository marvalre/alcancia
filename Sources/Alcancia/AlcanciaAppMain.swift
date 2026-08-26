import SwiftUI
import AlcanciaCore

@main
struct AlcanciaAppMain: App {
    @StateObject private var store = AlcanciaStore()

    /// Nivel de llenado del cerdito: `nil` cuando no hay meta, así se queda vacío.
    private var goalFraction: Double? {
        GoalProgress(totalMXN: store.totalMXN, goalMXN: store.data.goalMXN).fraction
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(store: store)
        } label: {
            Image(nsImage: PiggyBankIcon.image(
                progress: goalFraction,
                accessibilityDescription: store.menuBarSummary
            ))
        }
        .menuBarExtraStyle(.window)
    }
}
