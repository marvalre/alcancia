// Sources/Alcancia/AlcanciaAppMain.swift
import AppKit
import SwiftUI
import AlcanciaCore

/// Libera el atajo global al salir, como pide el diseño ("se libera al
/// salir"). Carbon lo limpiaría solo al morir el proceso, pero hacerlo
/// explícito evita depender de eso.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
    }
}

@main
struct AlcanciaAppMain: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: AlcanciaStore
    @StateObject private var desktopPanel: DesktopPanelController
    @StateObject private var quickCapture: QuickCaptureController

    init() {
        let store = AlcanciaStore()
        _store = StateObject(wrappedValue: store)
        _desktopPanel = StateObject(wrappedValue: DesktopPanelController(store: store))
        let quickCapture = QuickCaptureController(store: store)
        _quickCapture = StateObject(wrappedValue: quickCapture)

        // Registrado aquí, no en `.onAppear` del contenido del `MenuBarExtra`:
        // con `.menuBarExtraStyle(.window)` ese contenido se crea perezosamente
        // hasta el primer clic en el ícono, así que el atajo global no
        // funcionaría hasta que el usuario ya hubiera usado el mouse una vez.
        // `init()` de `App` corre al arrancar, garantizado, así que el atajo
        // queda vivo desde el primer instante.
        HotKeyManager.shared.register {
            quickCapture.toggle()
        }
    }

    /// El cerdito muestra lo que queda del presupuesto del mes en curso:
    /// lleno al empezar, vacío cuando se acabó.
    private var remainingFraction: Double? {
        store.budgetProgress(for: Date()).fractionRemaining
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(store: store)
                .onAppear {
                    desktopPanel.update(shows: store.data.showsDesktopPanel)
                }
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
