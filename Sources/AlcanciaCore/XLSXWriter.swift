import Foundation

struct XLSXWriter {
    private let data: AlcanciaData
    private let calendar: Calendar

    init(data: AlcanciaData, calendar: Calendar) {
        self.data = data
        self.calendar = calendar
    }

    func makeData() -> Data {
        var archive = ZIPArchiveWriter()
        archive.addFile(named: "[Content_Types].xml", data: xml(contentTypes()))
        archive.addFile(named: "_rels/.rels", data: xml(rootRelationships()))
        archive.addFile(named: "xl/workbook.xml", data: xml(workbook()))
        archive.addFile(named: "xl/_rels/workbook.xml.rels", data: xml(workbookRelationships()))
        archive.addFile(named: "xl/styles.xml", data: xml(styles()))
        archive.addFile(named: "xl/worksheets/sheet1.xml", data: xml(movementsSheet()))
        archive.addFile(named: "xl/worksheets/sheet2.xml", data: xml(monthlySummarySheet()))
        archive.addFile(named: "xl/worksheets/sheet3.xml", data: xml(balanceAdjustmentsSheet()))
        archive.addFile(named: "xl/worksheets/sheet4.xml", data: xml(recurrencesSheet()))
        return archive.makeData()
    }

    private func movementsSheet() -> String {
        let header = ["Fecha", "Tipo", "Categoría", "Concepto", "Moneda", "Monto", "Monto MXN", "Negocio", "Tasa USD", "ID recurrente", "Periodo recurrente"]
        let sortedEntries = data.entries.sorted { $0.date < $1.date }
        var rows = [row(1, header.map(stringCell))]
        for (index, entry) in sortedEntries.enumerated() {
            rows.append(row(index + 2, [
                stringCell(DataExporter.isoDate(entry.date)),
                stringCell(entry.kind == .income ? "Ingreso" : "Gasto"),
                stringCell(entry.category?.label ?? ""),
                stringCell(entry.note ?? ""),
                stringCell(entry.currency.rawValue.uppercased()),
                numberCell(entry.amount),
                numberCell(entry.amountInMXN),
                stringCell(entry.isBusiness ? "Sí" : "No"),
                entry.exchangeRateUsed.map { numberCell(Decimal($0)) } ?? stringCell(""),
                stringCell(entry.recurringExpenseID?.uuidString ?? ""),
                stringCell(entry.recurringPeriod.map(monthString) ?? "")
            ]))
        }
        return worksheet(rows)
    }

    private func monthlySummarySheet() -> String {
        var monthKeys = Set(data.entries.map { MonthKey(date: $0.date, calendar: calendar) })
        monthKeys.formUnion(data.monthlyBudgets.keys)
        monthKeys.formUnion(data.balanceAdjustments.map { MonthKey(date: $0.date, calendar: calendar) })
        if monthKeys.isEmpty { monthKeys.insert(MonthKey(date: Date(), calendar: calendar)) }

        var rows = [row(1, ["Mes", "Ingresos MXN", "Gastos MXN", "Saldo neto", "Presupuesto MXN"].map(stringCell))]
        for (index, month) in monthKeys.sorted().enumerated() {
            let excelRow = index + 2
            let income = formulaCell("SUMIFS(Movimientos!$G:$G,Movimientos!$B:$B,\"Ingreso\",Movimientos!$A:$A,A\(excelRow)&amp;\"*\")")
            let expense = formulaCell("SUMIFS(Movimientos!$G:$G,Movimientos!$B:$B,\"Gasto\",Movimientos!$A:$A,A\(excelRow)&amp;\"*\")")
            let monthlyEntries = data.entries.filter { MonthKey(date: $0.date, calendar: calendar) == month }
            let incomeCache = monthlyEntries.filter { $0.kind == .income }.reduce(Decimal(0)) { $0 + $1.amountInMXN }
            let expenseCache = monthlyEntries.filter { $0.kind == .expense }.reduce(Decimal(0)) { $0 + $1.amountInMXN }
            rows.append(row(excelRow, [stringCell(monthString(month)), formulaCell(income, cached: incomeCache), formulaCell(expense, cached: expenseCache), formulaCell("B\(excelRow)-C\(excelRow)", cached: incomeCache - expenseCache), data.monthlyBudgets[month].map(numberCell) ?? stringCell("")]))
        }
        return worksheet(rows)
    }

    private func balanceAdjustmentsSheet() -> String {
        var rows = [row(1, ["Fecha", "Saldo declarado MXN", "Nota"].map(stringCell))]
        for (index, adjustment) in data.balanceAdjustments
            .sorted(by: { $0.date < $1.date })
            .enumerated() {
            rows.append(row(index + 2, [
                stringCell(DataExporter.isoDate(adjustment.date)),
                numberCell(adjustment.amountMXN),
                stringCell(adjustment.note ?? "")
            ]))
        }
        return worksheet(rows)
    }

    private func recurrencesSheet() -> String {
        var rows = [row(1, ["ID", "Nombre", "Monto MXN", "Categoría", "Negocio", "Periodos omitidos"].map(stringCell))]
        for (index, recurring) in data.recurringExpenses.enumerated() {
            rows.append(row(index + 2, [
                stringCell(recurring.id.uuidString),
                stringCell(recurring.name),
                numberCell(recurring.amountMXN),
                stringCell(recurring.category.label),
                stringCell(recurring.isBusiness ? "Sí" : "No"),
                stringCell((data.skippedRecurringPeriods[recurring.id] ?? []).sorted().map(monthString).joined(separator: ", "))
            ]))
        }
        return worksheet(rows)
    }

    private func worksheet(_ rows: [String]) -> String {
        "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData>\(rows.joined())</sheetData></worksheet>"
    }

    private func row(_ index: Int, _ cells: [String]) -> String {
        let serializedCells = cells.enumerated().map { column, cell in
            let coordinate = "\(columnName(column + 1))\(index)"
            let type = cell.hasPrefix("<is>") ? " t=\"inlineStr\"" : ""
            return "<c r=\"\(coordinate)\"\(type)>\(cell)</c>"
        }.joined()
        return "<row r=\"\(index)\">\(serializedCells)</row>"
    }

    private func stringCell(_ value: String) -> String {
        "<is><t>\(escape(value))</t></is>"
    }

    private func numberCell(_ value: Decimal) -> String {
        "<v>\(DataExporter.decimalString(value))</v>"
    }

    private func formulaCell(_ formula: String, cached: Decimal = 0) -> String {
        "<f>\(formula)</f><v>\(DataExporter.decimalString(cached))</v>"
    }

    private func columnName(_ number: Int) -> String {
        String(UnicodeScalar(64 + number)!)
    }

    private func xml(_ value: String) -> Data { Data(value.utf8) }

    private func escape(_ value: String) -> String {
        String(value.unicodeScalars.filter { scalar in
            scalar.value == 0x9 || scalar.value == 0xA || scalar.value == 0xD || scalar.value >= 0x20
        })
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func monthString(_ month: MonthKey) -> String {
        String(format: "%04d-%02d", month.year, month.month)
    }

    private func contentTypes() -> String {
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/><Override PartName=\"/xl/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\"/><Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/><Override PartName=\"/xl/worksheets/sheet2.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/><Override PartName=\"/xl/worksheets/sheet3.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/><Override PartName=\"/xl/worksheets/sheet4.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/></Types>"
    }

    private func rootRelationships() -> String {
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>"
    }

    private func workbook() -> String {
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets><sheet name=\"Movimientos\" sheetId=\"1\" r:id=\"rId1\"/><sheet name=\"Resumen mensual\" sheetId=\"2\" r:id=\"rId2\"/><sheet name=\"Ajustes de saldo\" sheetId=\"3\" r:id=\"rId3\"/><sheet name=\"Recurrentes\" sheetId=\"4\" r:id=\"rId4\"/></sheets><calcPr calcMode=\"auto\" fullCalcOnLoad=\"1\" forceFullCalc=\"1\"/></workbook>"
    }

    private func workbookRelationships() -> String {
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/><Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet2.xml\"/><Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet3.xml\"/><Relationship Id=\"rId4\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet4.xml\"/><Relationship Id=\"rId5\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/></Relationships>"
    }

    private func styles() -> String {
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><styleSheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><fonts count=\"1\"><font><name val=\"Arial\"/><sz val=\"11\"/></font></fonts><fills count=\"1\"><fill><patternFill patternType=\"none\"/></fill></fills><borders count=\"1\"><border/></borders><cellStyleXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellStyleXfs><cellXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\"/></cellXfs><cellStyles count=\"1\"><cellStyle name=\"Normal\" xfId=\"0\" builtinId=\"0\"/></cellStyles><dxfs count=\"0\"/><tableStyles count=\"0\" defaultTableStyle=\"TableStyleMedium2\" defaultPivotStyle=\"PivotStyleLight16\"/></styleSheet>"
    }
}
