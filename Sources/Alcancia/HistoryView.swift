// Sources/Alcancia/HistoryView.swift
import SwiftUI
import AlcanciaCore

/// Los movimientos del mes que se está viendo, del más reciente al más viejo.
struct HistoryView: View {
    @ObservedObject var store: AlcanciaStore
    let summary: MonthlySummary
    var filter = EntryFilter()

    @State private var pendingDeleteID: UUID?
    @State private var editingID: UUID?
    @State private var undoAction: UndoAction?
    @State private var operationError: String?

    var body: some View {
        VStack(spacing: 0) {
            if let undoAction {
                HStack {
                    Text(undoAction.message).font(.caption)
                    Spacer()
                    Button("Deshacer") { undo(undoAction) }
                        .buttonStyle(.borderless)
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.12))
            }
            if let operationError {
                Text(operationError).font(.caption).foregroundStyle(.red).padding(.horizontal, 14)
            }
            Group {
                if visibleEntries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(visibleEntries) { entry in
                                VStack(spacing: 0) {
                                    row(for: entry)
                                    Divider()
                                }
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .top)),
                                        removal: .opacity.combined(with: .move(edge: .leading))
                                    )
                                )
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var visibleEntries: [Entry] {
        filter.apply(to: summary.entriesInMonth)
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text(summary.entriesInMonth.isEmpty ? "Sin movimientos este mes" : "Sin resultados")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func row(for entry: Entry) -> some View {
        Group {
            if pendingDeleteID == entry.id {
                deleteConfirmation(for: entry)
            } else if editingID == entry.id {
                EntryEditorView(
                    store: store,
                    entry: entry,
                    onCancel: { editingID = nil },
                    onSaved: { original, _ in
                        undoAction = UndoAction(entry: original, kind: .restoreEdit)
                        editingID = nil
                    }
                )
            } else {
                contentRow(for: entry)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    /// La confirmación va dentro de la propia fila. Un diálogo aparte abriría
    /// otra ventana, y el panel de la barra de menú se cierra en cuanto pierde
    /// el foco — se llevaría el diálogo con él antes de que se pueda contestar.
    private func deleteConfirmation(for entry: Entry) -> some View {
        HStack(spacing: 8) {
            Text("¿Borrar \(title(for: entry))?")
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            Button("Cancelar") {
                pendingDeleteID = nil
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Borrar") {
                // Con resorte y sin rebote: la fila se va, no salta.
                withAnimation(.spring(response: 0.3, dampingFraction: 1)) {
                    store.deleteEntry(id: entry.id)
                    if !store.data.entries.contains(where: { $0.id == entry.id }) {
                        undoAction = UndoAction(entry: entry, kind: .restoreDeletion)
                    } else {
                        operationError = "No se pudo borrar el movimiento."
                    }
                    pendingDeleteID = nil
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.red)
        }
    }

    private func contentRow(for entry: Entry) -> some View {
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
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 1), value: entry.amountInMXN)
                    .foregroundStyle(entry.kind == .expense ? Color.primary : Color.green)
                if entry.currency == .usd {
                    Text("USD \(entry.amount.description)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                editingID = entry.id
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Editar \(title(for: entry))")

            Button {
                pendingDeleteID = entry.id
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Borrar \(title(for: entry))")
        }
    }

    private func undo(_ action: UndoAction) {
        let result: Result<Void, StoreError>
        switch action.kind {
        case .restoreDeletion: result = store.restoreEntry(action.entry)
        case .restoreEdit: result = store.updateEntry(action.entry)
        }
        switch result {
        case .success:
            undoAction = nil
            operationError = nil
        case .failure:
            operationError = "No se pudo deshacer el último cambio."
        }
    }

    private struct UndoAction {
        enum Kind { case restoreDeletion, restoreEdit }
        let entry: Entry
        let kind: Kind
        var message: String { kind == .restoreDeletion ? "Movimiento borrado" : "Movimiento editado" }
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
