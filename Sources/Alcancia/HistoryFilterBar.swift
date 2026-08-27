import SwiftUI
import AlcanciaCore

struct HistoryFilterBar: View {
    @Binding var filter: EntryFilter

    private var hasActiveFilters: Bool {
        filter.kind != nil || filter.category != nil || filter.business != nil
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField("Buscar concepto", text: $filter.query)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .accessibilityLabel("Buscar movimientos por concepto")

            Menu {
                Picker("Tipo", selection: $filter.kind) {
                    Text("Todos").tag(EntryKind?.none)
                    Text("Gastos").tag(EntryKind?.some(.expense))
                    Text("Ingresos").tag(EntryKind?.some(.income))
                }

                Picker("Categoría", selection: $filter.category) {
                    Text("Todas").tag(ExpenseCategory?.none)
                    ForEach(ExpenseCategory.allCases) { category in
                        Text("\(category.emoji) \(category.label)")
                            .tag(ExpenseCategory?.some(category))
                    }
                }

                Picker("Uso", selection: $filter.business) {
                    Text("Todos").tag(Bool?.none)
                    Text("Negocio").tag(Bool?.some(true))
                    Text("Personal").tag(Bool?.some(false))
                }

                if hasActiveFilters {
                    Divider()
                    Button("Limpiar filtros") {
                        filter.kind = nil
                        filter.category = nil
                        filter.business = nil
                    }
                }
            } label: {
                Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }
            .menuStyle(.borderlessButton)
            .help("Filtrar movimientos")
            .accessibilityLabel("Filtrar movimientos")
            .accessibilityValue(hasActiveFilters ? "Filtros activos" : "Sin filtros")
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }
}
