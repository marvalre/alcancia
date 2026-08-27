// Sources/Alcancia/MenuBarView.swift
import SwiftUI
import AlcanciaCore

struct MenuBarView: View {
    @ObservedObject var store: AlcanciaStore

    @State private var month = Date()
    @State private var listMode: ListMode = .movimientos
    @State private var showingSettings = false

    private enum ListMode: String, CaseIterable, Identifiable {
        case movimientos = "Movimientos"
        case categorias = "Por categoría"
        var id: String { rawValue }
    }

    private var summary: MonthlySummary { store.summary(for: month) }

    /// `logRecurring` sólo es idempotente para el mes en curso (ver el report
    /// de Core): no se ofrece mientras se navega a otro mes.
    private var isBrowsingCurrentMonth: Bool {
        Calendar.current.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    private var unloggedRecurring: [RecurringExpense] {
        isBrowsingCurrentMonth ? store.unloggedRecurring(for: month) : []
    }

    var body: some View {
        Group {
            if showingSettings {
                SettingsView(store: store, onClose: { showingSettings = false })
            } else {
                mainContent
            }
        }
        .frame(width: 360, height: 560)
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            MonthHeaderView(store: store, month: $month, onOpenSettings: { showingSettings = true })
            Divider()
            QuickAddView(store: store)
            Divider()

            Picker("Vista", selection: $listMode) {
                ForEach(ListMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            if !unloggedRecurring.isEmpty {
                recurringBanner
            }

            switch listMode {
            case .movimientos:
                HistoryView(store: store, summary: summary)
            case .categorias:
                CategoryBreakdownView(store: store, summary: summary)
            }

            Divider()
            footer
        }
    }

    /// Franja discreta, no una alarma: registrar recurrentes es una
    /// conveniencia opcional, no algo que falló.
    private var recurringBanner: some View {
        HStack(spacing: 8) {
            Text(recurringBannerText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Button("Registrar") {
                store.logRecurring(for: month)
            }
            .buttonStyle(.borderless)
            .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.12))
    }

    private var recurringBannerText: String {
        let count = unloggedRecurring.count
        let noun = count == 1 ? "suscripción sin registrar" : "suscripciones sin registrar"
        return "\(count) \(noun) este mes"
    }

    private var footer: some View {
        HStack {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(.borderless)

            Spacer()

            Button("Salir") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
