import Foundation

public enum MoneyParser {
    /// Acepta el separador local y las variantes usuales de es_MX. Sólo devuelve montos positivos.
    public static func parse(_ text: String, locale: Locale = .current) -> Decimal? {
        guard let amount = parseRaw(text, locale: locale), amount > 0 else { return nil }
        return amount
    }

    /// Para saldos declarados: permite cero y deuda, pero conserva el mismo
    /// tratamiento localizado de separadores que la captura de movimientos.
    public static func parseBalance(_ text: String, locale: Locale = .current) -> Decimal? {
        parseRaw(text, locale: locale)
    }

    private static func parseRaw(_ text: String, locale: Locale) -> Decimal? {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        value = value.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "MXN", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "USD", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " ", with: "")

        let comma = value.lastIndex(of: ",")
        let dot = value.lastIndex(of: ".")
        let decimalSeparator: Character?
        switch (comma, dot) {
        case let (.some(c), .some(d)): decimalSeparator = c > d ? "," : "."
        case let (.some(c), .none):
            decimalSeparator = value.distance(from: value.index(after: c), to: value.endIndex) <= 2 ? "," : nil
        case let (.none, .some(d)):
            decimalSeparator = value.distance(from: value.index(after: d), to: value.endIndex) <= 2 ? "." : nil
        case (.none, .none): decimalSeparator = nil
        }

        var normalized = ""
        for character in value where character.isNumber || character == "," || character == "." || character == "-" {
            if character == decimalSeparator { normalized.append(".") }
            else if character != "," && character != "." { normalized.append(character) }
        }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }
}
