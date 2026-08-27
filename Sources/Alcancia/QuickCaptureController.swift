// Sources/Alcancia/QuickCaptureController.swift
import AppKit
import SwiftUI
import AlcanciaCore

/// Un `NSPanel` `.nonactivatingPanel` no puede volverse "key" por defecto, y
/// a diferencia del panel de escritorio, este sí necesita el foco de
/// teclado apenas aparece: el usuario está a punto de escribir el monto.
/// De ahí la subclase.
private final class KeyableHotKeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Ventanita flotante de captura para el atajo global. Modelada sobre
/// `DesktopPanelController`, pero esta sí toma el foco: se activa la app y
/// se hace "key" el panel apenas se muestra.
@MainActor
final class QuickCaptureController: ObservableObject {
    private var panel: NSPanel?
    private let store: AlcanciaStore

    init(store: AlcanciaStore) {
        self.store = store
    }

    func toggle() {
        if panel != nil {
            close()
        } else {
            show()
        }
    }

    private func show() {
        let hosting = NSHostingController(
            rootView: QuickCaptureView(store: store, onFinished: { [weak self] in
                self?.close()
            })
        )
        let size = NSSize(width: 360, height: 150)
        hosting.view.frame = NSRect(origin: .zero, size: size)

        let panel = KeyableHotKeyPanel(
            contentRect: hosting.view.frame,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false

        // Centrada en la pantalla donde está el mouse, no siempre la
        // pantalla principal.
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
        if let frame = targetScreen?.frame {
            let origin = NSPoint(
                x: frame.midX - size.width / 2,
                y: frame.midY - size.height / 2
            )
            panel.setFrameOrigin(origin)
        } else {
            panel.center()
        }

        // A diferencia del panel de escritorio, este necesita robarle el
        // foco a lo que sea que esté activo, porque el usuario va a teclear
        // de inmediato.
        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func close() {
        panel?.orderOut(nil)
        panel?.contentViewController = nil
        panel = nil
    }
}
