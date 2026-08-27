import Carbon.HIToolbox

enum HotKeyShortcut: String, CaseIterable, Identifiable {
    case optionCommandA
    case optionCommandG
    case controlOptionA
    case controlCommandA

    static let defaultsKey = "globalHotKeyShortcut"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .optionCommandA: return "⌥⌘A"
        case .optionCommandG: return "⌥⌘G"
        case .controlOptionA: return "⌃⌥A"
        case .controlCommandA: return "⌃⌘A"
        }
    }

    var keyCode: UInt32 {
        switch self {
        case .optionCommandG: return UInt32(kVK_ANSI_G)
        default: return UInt32(kVK_ANSI_A)
        }
    }

    var modifiers: UInt32 {
        switch self {
        case .optionCommandA, .optionCommandG:
            return UInt32(optionKey | cmdKey)
        case .controlOptionA:
            return UInt32(controlKey | optionKey)
        case .controlCommandA:
            return UInt32(controlKey | cmdKey)
        }
    }

    static var saved: HotKeyShortcut {
        guard let raw = UserDefaults.standard.string(forKey: defaultsKey),
              let shortcut = HotKeyShortcut(rawValue: raw)
        else { return .optionCommandA }
        return shortcut
    }

    func persist() {
        UserDefaults.standard.set(rawValue, forKey: Self.defaultsKey)
    }
}
