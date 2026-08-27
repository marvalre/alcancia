import Foundation
import XCTest
@testable import AlcanciaCore

final class DataExporterTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func sampleData(note: String = "Café \"La, Plaza\"") -> AlcanciaData {
        AlcanciaData(
            monthlyBudgetMXN: 5_000,
            monthlyBudgets: [MonthKey(year: 2026, month: 7): 4_000],
            balanceAdjustments: [BalanceAdjustment(amountMXN: 8_000, date: date(2026, 7, 1), note: "Saldo inicial")],
            skippedRecurringPeriods: [UUID(uuidString: "33333333-3333-3333-3333-333333333333")!: [MonthKey(year: 2026, month: 7)]],
            entries: [
                Entry(
                    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    amount: 125.50,
                    currency: .mxn,
                    amountInMXN: 125.50,
                    date: date(2026, 8, 15),
                    kind: .expense,
                    category: .comida,
                    note: note,
                    isBusiness: true
                ),
                Entry(
                    id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                    amount: 1_000,
                    currency: .mxn,
                    amountInMXN: 1_000,
                    date: date(2026, 8, 1),
                    kind: .income,
                    note: "Nómina"
                )
            ],
            recurringExpenses: [
                RecurringExpense(
                    id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                    name: "Música ñ",
                    amountMXN: 129,
                    category: .ocio
                )]
        )
    }

    /// Protege contra CSV inválido, fórmulas de Excel y acentos mal decodificados.
    func testCSVQuotesFieldsAndUsesSpanishHeaders() throws {
        let csv = String(
            decoding: try DataExporter.export(data: sampleData(), format: .csv, calendar: calendar),
            as: UTF8.self
        )

        XCTAssertTrue(csv.hasPrefix("\u{FEFF}Fecha,Tipo,Categoría,Concepto,Moneda,Monto,Monto MXN,Negocio\r\n"))
        XCTAssertTrue(csv.contains("\"Café \"\"La, Plaza\"\"\""))
        XCTAssertTrue(csv.contains("2026-08-15"))
    }

    func testCSVNeutralizesSpreadsheetFormulaInjection() throws {
        let csv = String(decoding: try DataExporter.export(
            data: sampleData(note: "=HYPERLINK(\"https://malicious.example\")"),
            format: .csv,
            calendar: calendar
        ), as: UTF8.self)

        XCTAssertTrue(csv.contains("'=HYPERLINK"))
    }

    /// Protege contra archivos JSON que no puedan reimportarse o que serialicen fechas ambiguas.
    func testJSONRoundTripsCompleteDataWithISO8601Dates() throws {
        let exported = try DataExporter.export(data: sampleData(), format: .json, calendar: calendar)
        let text = try XCTUnwrap(String(data: exported, encoding: .utf8))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AlcanciaData.self, from: exported)

        XCTAssertTrue(text.contains("2026-08-15T"))
        XCTAssertEqual(decoded.entries, sampleData().entries)
        XCTAssertEqual(decoded.recurringExpenses, sampleData().recurringExpenses)
    }

    /// Protege contra entregar un CSV renombrado en lugar de un libro OOXML nativo.
    func testXLSXIsZipWithRequiredSheetsFormulasAndUnicode() throws {
        let workbook = try DataExporter.export(data: sampleData(), format: .xlsx, calendar: calendar)
        let xml = String(decoding: workbook, as: UTF8.self)

        if let artifactPath = ProcessInfo.processInfo.environment["ALCANCIA_XLSX_ARTIFACT"] {
            try workbook.write(to: URL(fileURLWithPath: artifactPath), options: .atomic)
        }

        XCTAssertEqual(Array(workbook.prefix(4)), [0x50, 0x4B, 0x03, 0x04])
        XCTAssertTrue(xml.contains("Movimientos"))
        XCTAssertTrue(xml.contains("Resumen mensual"))
        XCTAssertTrue(xml.contains("Ajustes de saldo"))
        XCTAssertTrue(xml.contains("Recurrentes"))
        XCTAssertTrue(xml.contains("SUMIFS("))
        XCTAssertTrue(xml.contains("Café"))
        XCTAssertTrue(xml.contains("Arial"))
        XCTAssertTrue(xml.contains("Presupuesto MXN"))
        XCTAssertTrue(xml.contains("Tasa USD"))
        XCTAssertTrue(xml.contains("ID recurrente"))
        XCTAssertTrue(xml.contains("Periodos omitidos"))
        XCTAssertTrue(xml.contains("2026-07"))
        XCTAssertTrue(xml.contains("<v>1000</v>"))
    }

    func testXLSXStripsXMLControlCharactersFromUserText() throws {
        let workbook = try DataExporter.export(
            data: sampleData(note: "Texto\u{000B} no válido"),
            format: .xlsx,
            calendar: calendar
        )

        // Buscar el byte 0x0B en el ZIP completo es falso positivo: los
        // encabezados locales llevan un CRC32 binario de 4 bytes por
        // archivo, y ese checksum puede coincidir con 0x0B por pura
        // casualidad sin que el texto del usuario tenga nada que ver.
        // Se extrae el contenido real (sin comprimir) de sheet1.xml, la
        // única hoja donde vive el concepto del usuario, y se revisa ahí.
        let sheet1 = try extractStoredZipEntry(named: "xl/worksheets/sheet1.xml", from: workbook)
        let xml = String(decoding: sheet1, as: UTF8.self)

        XCTAssertFalse(
            xml.unicodeScalars.contains(Unicode.Scalar(0x0B)!),
            "el carácter de control no debió sobrevivir al XML de la hoja"
        )
        XCTAssertTrue(xml.contains("Texto no válido"), "el resto del texto sí debe conservarse")
    }

    /// Extrae el contenido almacenado (sin comprimir) de una entrada del ZIP
    /// mínimo que produce `ZIPArchiveWriter`. No es un lector ZIP de
    /// propósito general: sólo entiende el formato exacto (método 0, sin
    /// campo extra) que el propio escritor genera, leyendo su encabezado
    /// local de 30 bytes directamente.
    private func extractStoredZipEntry(named target: String, from archive: Data) throws -> Data {
        let signature: [UInt8] = [0x50, 0x4B, 0x03, 0x04]
        var offset = archive.startIndex
        while offset + 30 <= archive.endIndex {
            let header = Array(archive[offset..<offset + 30])
            guard Array(header.prefix(4)) == signature else { break }
            func u16(_ i: Int) -> Int { Int(header[i]) | (Int(header[i + 1]) << 8) }
            func u32(_ i: Int) -> Int {
                Int(header[i]) | (Int(header[i + 1]) << 8) | (Int(header[i + 2]) << 16) | (Int(header[i + 3]) << 24)
            }
            let compressedSize = u32(18)
            let nameLength = u16(26)
            let extraLength = u16(28)
            let nameStart = offset + 30
            let nameEnd = nameStart + nameLength
            let name = String(decoding: archive[nameStart..<nameEnd], as: UTF8.self)
            let dataStart = nameEnd + extraLength
            let dataEnd = dataStart + compressedSize
            if name == target {
                return archive[dataStart..<dataEnd]
            }
            offset = dataEnd
        }
        struct EntryNotFound: Error, CustomStringConvertible {
            let name: String
            var description: String { "No se encontró la entrada '\(name)' en el zip" }
        }
        throw EntryNotFound(name: target)
    }
}
