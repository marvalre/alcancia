// Sources/Alcancia/HotKeyManager.swift
import AppKit
import Carbon.HIToolbox

/// Atajo global registrado con Carbon. Se usa `RegisterEventHotKey` en vez de
/// un monitor global de `NSEvent` porque este no pide permisos de
/// accesibilidad al usuario.
@MainActor
final class HotKeyManager: ObservableObject {
    static let shared = HotKeyManager()

    @Published private(set) var registrationError: String?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var onPressed: (() -> Void)?

    private init() {}

    /// Por defecto ⌥⌘A. Devuelve `true` sólo cuando Carbon registró tanto el
    /// manejador como la combinación; un conflicto nunca queda silencioso.
    @discardableResult
    func register(
        shortcut: HotKeyShortcut = .optionCommandA,
        onPressed: (() -> Void)? = nil
    ) -> Bool {
        unregister()
        if let onPressed { self.onPressed = onPressed }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        // El callback de Carbon es un puntero a función de C: no puede
        // capturar contexto, así que se llega a la instancia por el singleton.
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ in
                Task { @MainActor in HotKeyManager.shared.onPressed?() }
                return noErr
            },
            1, &eventType, nil, &handlerRef
        )
        guard handlerStatus == noErr else {
            registrationError = "No se pudo preparar el atajo (código \(handlerStatus))."
            handlerRef = nil
            return false
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x414C4341), id: 1) // 'ALCA'
        let hotKeyStatus = RegisterEventHotKey(
            shortcut.keyCode, shortcut.modifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
        guard hotKeyStatus == noErr else {
            if let handlerRef { RemoveEventHandler(handlerRef) }
            self.handlerRef = nil
            hotKeyRef = nil
            registrationError = "El atajo \(shortcut.label) está ocupado. Elige otro en Ajustes."
            return false
        }
        shortcut.persist()
        registrationError = nil
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }
}
