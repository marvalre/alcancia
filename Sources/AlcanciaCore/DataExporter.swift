import Foundation

public enum DataExportFormat: String, CaseIterable, Sendable {
    case csv
    case json
    case xlsx
}

public enum DataExportError: LocalizedError {
    case encodingFailed

    public var errorDescription: String? {
        "No se pudieron preparar los datos para exportar."
    }
}

/// Serializa el estado que ya está cargado en memoria. No conoce AppKit ni toca
/// el sistema de archivos: la interfaz decide dónde guardar los bytes.
public enum DataExporter {
    public static func export(
        data: AlcanciaData,
        format: DataExportFormat,
        calendar: Calendar = .current
    ) throws -> Data {
        switch format {
        case .csv:
            return Data([0xEF, 0xBB, 0xBF]) + Data(csv(data.entries).utf8)
        case .json:
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(data)
        case .xlsx:
            return XLSXWriter(data: data, calendar: calendar).makeData()
        }
    }

    private static func csv(_ entries: [Entry]) -> String {
        let header = ["Fecha", "Tipo", "Categoría", "Concepto", "Moneda", "Monto", "Monto MXN", "Negocio"]
        let rows = entries
            .sorted { $0.date < $1.date }
            .map { entry in
                [
                    isoDate(entry.date),
                    entry.kind == .income ? "Ingreso" : "Gasto",
                    entry.category?.label ?? "",
                    entry.note ?? "",
                    entry.currency.rawValue.uppercased(),
                    decimalString(entry.amount),
                    decimalString(entry.amountInMXN),
                    entry.isBusiness ? "Sí" : "No"
                ]
            }
        return ([header] + rows)
            .map { $0.map(csvField).joined(separator: ",") }
            .joined(separator: "\r\n") + "\r\n"
    }

    static func isoDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    static func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private static func csvField(_ value: String) -> String {
        let safeValue: String
        if let first = value.first, "=+-@".contains(first) {
            safeValue = "'\(value)"
        } else {
            safeValue = value
        }
        guard safeValue.contains(where: { ",\"\r\n".contains($0) }) else { return safeValue }
        return "\"\(safeValue.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
