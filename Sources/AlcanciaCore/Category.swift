import Foundation

/// Las categorías de gasto. Son fijas a propósito: elegir de ocho emojis es
/// un clic, y mantener la captura por debajo de tres segundos manda sobre la
/// flexibilidad de tener categorías personalizadas.
public enum Category: String, Codable, CaseIterable, Identifiable, Sendable {
    case comida
    case mercado
    case transporte
    case casa
    case software
    case ocio
    case salud
    case otro

    public var id: String { rawValue }

    public var emoji: String {
        switch self {
        case .comida: return "🍔"
        case .mercado: return "🛒"
        case .transporte: return "🚗"
        case .casa: return "🏠"
        case .software: return "💻"
        case .ocio: return "🎬"
        case .salud: return "💊"
        case .otro: return "📦"
        }
    }

    public var label: String {
        switch self {
        case .comida: return "Comida"
        case .mercado: return "Súper"
        case .transporte: return "Transporte"
        case .casa: return "Casa"
        case .software: return "Software"
        case .ocio: return "Ocio"
        case .salud: return "Salud"
        case .otro: return "Otro"
        }
    }
}
