// Sources/Alcancia/HistoryView.swift
import SwiftUI
import AlcanciaCore

struct HistoryView: View {
    @ObservedObject var store: AlcanciaStore
    @State private var pendingDeleteID: UUID?

    private var sortedEntries: [Entry] {
        store.data.entries.sorted { $0.date > $1.date }
    }

    var body: some View {
        Group {
            if sortedEntries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sortedEntries) { entry in
                            row(for: entry)
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .confirmationDialog(
            "¿Borrar esta entrada?",
            isPresented: Binding(
                get: { pendingDeleteID != nil },
                set: { isPresented in
                    if !isPresented { pendingDeleteID = nil }
                }
            )
        ) {
            Button("Borrar", role: .destructive) {
                if let id = pendingDeleteID {
                    store.deleteEntry(id: id)
                }
                pendingDeleteID = nil
            }
            Button("Cancelar", role: .cancel) {
                pendingDeleteID = nil
            }
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("Todavía no has agregado nada")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func row(for entry: Entry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.formattedAmount(entry.amountInMXN))
                    .font(.subheadline)
                Text(Self.dateFormatter.string(from: entry.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if entry.currency == .usd {
                Text("USD \(entry.amount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Button {
                pendingDeleteID = entry.id
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "es_MX")
        return formatter
    }()
}
