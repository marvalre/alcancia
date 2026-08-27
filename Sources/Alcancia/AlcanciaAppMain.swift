// Sources/Alcancia/AlcanciaAppMain.swift
import AppKit
import SwiftUI
import AlcanciaCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Lo puebla `AlcanciaAppMain.init()`. El panel de escritorio se restaura
    /// aquí y no en el `.onAppear` del contenido del `MenuBarExtra`, porque ese
    /// contenido se crea perezosamente hasta el primer clic en el ícono: un
    /// widget que sólo aparece después de invocarlo con el mouse no es un
    /// widget. Al arrancar la Mac tiene que estar ahí solo.
    static var restoreDesktopPanel: (@MainActor () -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            Self.restoreDesktopPanel?()
        }
    }

    /// Libera el atajo global al salir, como pide el diseño ("se libera al
    /// salir"). Carbon lo limpiaría solo al morir el proceso, pero hacerlo
    /// explícito evita depender de eso.
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
        let desktopPanel = DesktopPanelController(store: store)
        _desktopPanel = StateObject(wrappedValue: desktopPanel)
        let quickCapture = QuickCaptureController(store: store)
        _quickCapture = StateObject(wrappedValue: quickCapture)

        // Un clic en el panel del escritorio abre la captura rápida: así el
        // widget deja de ser decorativo y se vuelve el botón permanente de
        // "anotar un gasto".
        desktopPanel.onActivate = { quickCapture.toggle() }

        // El panel se levanta cuando la app termina de arrancar, no cuando el
        // usuario abre el menú.
        AppDelegate.restoreDesktopPanel = {
            desktopPanel.update(shows: store.data.showsDesktopPanel)
        }

        // El cerdito y el panel calculan sobre `Date()`. Sin esto, una Mac que
        // se queda prendida cruzando la medianoche del último día del mes
        // seguiría mostrando el mes que ya terminó hasta que algún otro cambio
        // forzara un redibujo. El observador vive lo que vive la app.
        NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                store.objectWillChange.send()
            }
        }

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
