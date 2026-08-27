// Sources/Alcancia/HotKeyManager.swift
import AppKit
import Carbon.HIToolbox

/// Atajo global registrado con Carbon. Se usa `RegisterEventHotKey` en vez de
/// un monitor global de `NSEvent` porque este no pide permisos de
/// accesibilidad al usuario.
@MainActor
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var onPressed: (() -> Void)?

    private init() {}

    /// Por defecto ⌥⌘A.
    func register(
        keyCode: UInt32 = UInt32(kVK_ANSI_A),
        modifiers: UInt32 = UInt32(optionKey | cmdKey),
        onPressed: @escaping () -> Void
    ) {
        unregister()
        self.onPressed = onPressed

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        // El callback de Carbon es un puntero a función de C: no puede
        // capturar contexto, así que se llega a la instancia por el singleton.
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ in
                Task { @MainActor in HotKeyManager.shared.onPressed?() }
                return noErr
            },
            1, &eventType, nil, &handlerRef
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x414C4341), id: 1) // 'ALCA'
        RegisterEventHotKey(
            keyCode, modifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
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
