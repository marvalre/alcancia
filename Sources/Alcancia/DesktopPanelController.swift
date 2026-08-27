// Sources/Alcancia/DesktopPanelController.swift
import AppKit
import SwiftUI
import AlcanciaCore

/// Un `NSPanel` sin bordes que flota sobre el escritorio. Es la alternativa
/// viable al widget de WidgetKit, que necesitaría un App Group y por lo tanto
/// una cuenta de desarrollador de Apple.
@MainActor
final class DesktopPanelController: ObservableObject {
    private var panel: NSPanel?
    private let store: AlcanciaStore
    private var frameObserver: NSObjectProtocol?

    /// Se dispara cuando el usuario hace clic en el panel. `AlcanciaAppMain`
    /// lo conecta a `quickCapture.toggle()` para que el panel funcione como
    /// acceso directo permanente a "agregar gasto" — el punto fuerte de un
    /// widget de escritorio. Es una propiedad (no un parámetro de `init`)
    /// porque `QuickCaptureController` se crea aparte, con el mismo store, y
    /// se conecta después de que ambos existen.
    var onActivate: (() -> Void)?

    init(store: AlcanciaStore) {
        self.store = store
    }

    func update(shows: Bool) {
        if shows {
            show()
        } else {
            hide()
        }
    }

    private func show() {
        if let panel {
            panel.orderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: DesktopPanelView(store: store, onActivate: { [weak self] in
            self?.onActivate?()
        }))
        hosting.view.frame = NSRect(x: 0, y: 0, width: 240, height: 110)

        let panel = NSPanel(
            contentRect: hosting.view.frame,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        if let origin = store.data.desktopPanelOrigin, origin.count == 2 {
            panel.setFrameOrigin(visibleOrigin(
                for: NSPoint(x: origin[0], y: origin[1]),
                panelSize: hosting.view.frame.size
            ))
        } else {
            panel.center()
        }

        // Guardamos la posición cuando el usuario suelta el panel, para
        // restaurarlo ahí la próxima vez.
        frameObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] notification in
            guard let moved = notification.object as? NSWindow else { return }
            let origin = moved.frame.origin
            Task { @MainActor in
                self?.store.setDesktopPanelOrigin(origin)
            }
        }

        panel.orderFront(nil)
        self.panel = panel
    }

    /// Una pantalla desconectada no puede dejar el panel perdido fuera del
    /// escritorio. Si todavía toca una pantalla, lo ajusta dentro de su área
    /// visible; si no, vuelve al centro de la pantalla principal.
    private func visibleOrigin(for saved: NSPoint, panelSize: NSSize) -> NSPoint {
        let proposed = NSRect(origin: saved, size: panelSize)
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(proposed) }) else {
            guard let frame = NSScreen.main?.visibleFrame else { return saved }
            return NSPoint(x: frame.midX - panelSize.width / 2, y: frame.midY - panelSize.height / 2)
        }

        let frame = screen.visibleFrame
        return NSPoint(
            x: min(max(saved.x, frame.minX), frame.maxX - panelSize.width),
            y: min(max(saved.y, frame.minY), frame.maxY - panelSize.height)
        )
    }

    private func hide() {
        if let frameObserver {
            NotificationCenter.default.removeObserver(frameObserver)
            self.frameObserver = nil
        }
        panel?.orderOut(nil)
        panel?.contentViewController = nil
        panel = nil
    }
}
