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
        // La posición del separador decimal, no el carácter: si el mismo
        // separador aparece más de una vez (p. ej. "1.234.56" al estilo
        // europeo, o "12,345,67"), sólo la ÚLTIMA ocurrencia es el punto
        // decimal. Las demás son separadores de miles y se descartan igual
        // que las del otro carácter. Antes se comparaba por VALOR del
        // carácter, así que todas las ocurrencias del separador elegido se
        // volvían punto — "1.234.56" truncaba en silencio a 1.234.
        let decimalIndex: String.Index?
        switch (comma, dot) {
        case let (.some(c), .some(d)): decimalIndex = c > d ? c : d
        case let (.some(c), .none):
            decimalIndex = value.distance(from: value.index(after: c), to: value.endIndex) <= 2 ? c : nil
        case let (.none, .some(d)):
            decimalIndex = value.distance(from: value.index(after: d), to: value.endIndex) <= 2 ? d : nil
        case (.none, .none): decimalIndex = nil
        }

        var normalized = ""
        for index in value.indices
        where value[index].isNumber || value[index] == "," || value[index] == "." || value[index] == "-" {
            let character = value[index]
            if index == decimalIndex { normalized.append(".") }
            else if character != "," && character != "." { normalized.append(character) }
        }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }
}
