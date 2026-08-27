import AppKit
import UniformTypeIdentifiers
import AlcanciaCore

@MainActor
enum ExportController {
    static func export(data: AlcanciaData, format: DataExportFormat) -> Result<URL, Error> {
        let panel = NSSavePanel()
        panel.title = "Exportar datos de Alcancía"
        panel.nameFieldStringValue = "Alcancia-\(dayStamp()).\(format.rawValue)"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [contentType(for: format)]

        guard panel.runModal() == .OK, let url = panel.url else {
            return .failure(CancellationError())
        }

        do {
            let payload = try DataExporter.export(data: data, format: format)
            try payload.write(to: url, options: .atomic)
            return .success(url)
        } catch {
            return .failure(error)
        }
    }

    private static func contentType(for format: DataExportFormat) -> UTType {
        switch format {
        case .csv: return .commaSeparatedText
        case .json: return .json
        case .xlsx: return UTType(filenameExtension: "xlsx") ?? .data
        }
    }

    private static func dayStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
