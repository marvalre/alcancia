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

    var body: some View {
        VStack(spacing: 0) {
            MonthHeaderView(store: store, month: $month)
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

            switch listMode {
            case .movimientos:
                HistoryView(store: store, summary: summary)
            case .categorias:
                CategoryBreakdownView(store: store, summary: summary)
            }

            Divider()
            footer
        }
        .frame(width: 360, height: 560)
        .sheet(isPresented: $showingSettings) {
            SettingsView(store: store)
        }
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
