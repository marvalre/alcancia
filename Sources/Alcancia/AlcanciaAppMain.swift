// Sources/Alcancia/AlcanciaAppMain.swift
import SwiftUI
import AlcanciaCore

@main
struct AlcanciaAppMain: App {
    @StateObject private var store = AlcanciaStore()

    /// El cerdito muestra lo que queda del presupuesto del mes en curso:
    /// lleno al empezar, vacío cuando se acabó.
    private var remainingFraction: Double? {
        store.budgetProgress(for: Date()).fractionRemaining
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(store: store)
        } label: {
            Image(nsImage: PiggyBankIcon.image(
                progress: remainingFraction,
                accessibilityDescription: store.menuBarAccessibilityLabel(for: Date())
            ))
        }
        .menuBarExtraStyle(.window)
    }
}
