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

        XCTAssertFalse(workbook.contains(0x0B))
    }
}
