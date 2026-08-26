// Sources/Alcancia/HistoryView.swift
import SwiftUI
import AlcanciaCore

/// Los movimientos del mes que se está viendo, del más reciente al más viejo.
struct HistoryView: View {
    @ObservedObject var store: AlcanciaStore
    let summary: MonthlySummary

    @State private var pendingDeleteID: UUID?

    var body: some View {
        Group {
            if summary.entriesInMonth.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(summary.entriesInMonth) { entry in
                            row(for: entry)
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .confirmationDialog(
            "¿Borrar este movimiento?",
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
            Text("Sin movimientos este mes")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func row(for entry: Entry) -> some View {
        HStack(spacing: 8) {
            Text(entry.kind == .expense ? (entry.category ?? .otro).emoji : "💰")

            VStack(alignment: .leading, spacing: 2) {
                Text(title(for: entry))
                    .font(.caption)
                Text(Self.dateFormatter.string(from: entry.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(signedAmount(for: entry))
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(entry.kind == .expense ? Color.primary : Color.green)
                if entry.currency == .usd {
                    Text("USD \(entry.amount.description)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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
        .padding(.vertical, 7)
    }

    private func title(for entry: Entry) -> String {
        if let note = entry.note, !note.isEmpty { return note }
        return entry.kind == .expense
            ? (entry.category ?? .otro).label
            : "Ingreso"
    }

    private func signedAmount(for entry: Entry) -> String {
        let sign = entry.kind == .expense ? "−" : "+"
        return sign + store.formattedAmount(entry.amountInMXN)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "es_MX")
        return formatter
    }()
}
