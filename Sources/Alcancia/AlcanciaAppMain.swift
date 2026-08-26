// Sources/Alcancia/AlcanciaAppMain.swift
import SwiftUI
import AlcanciaCore

@main
struct AlcanciaAppMain: App {
    @StateObject private var store: AlcanciaStore
    @StateObject private var desktopPanel: DesktopPanelController

    init() {
        let store = AlcanciaStore()
        _store = StateObject(wrappedValue: store)
        _desktopPanel = StateObject(wrappedValue: DesktopPanelController(store: store))
    }

    /// El cerdito muestra lo que queda del presupuesto del mes en curso:
    /// lleno al empezar, vacío cuando se acabó.
    private var remainingFraction: Double? {
        store.budgetProgress(for: Date()).fractionRemaining
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(store: store)
                .onAppear { desktopPanel.update(shows: store.data.showsDesktopPanel) }
                .onChange(of: store.data.showsDesktopPanel) { _, shows in
                    desktopPanel.update(shows: shows)
                }
        } label: {
            Image(nsImage: PiggyBankIcon.image(
                progress: remainingFraction,
                accessibilityDescription: store.menuBarAccessibilityLabel(for: Date())
            ))
        }
        .menuBarExtraStyle(.window)
    }
}
