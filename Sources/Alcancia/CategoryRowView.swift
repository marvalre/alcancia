// Sources/Alcancia/CategoryRowView.swift
import SwiftUI
import AlcanciaCore

/// Las ocho categorías en una fila de emojis. Elegir es un clic, no un menú
/// desplegable — la diferencia entre capturar en tres segundos o en diez.
struct CategoryRowView: View {
    @Binding var selection: ExpenseCategory

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ExpenseCategory.allCases) { category in
                Button {
                    selection = category
                } label: {
                    Text(category.emoji)
                        .font(.system(size: 15))
                        .frame(width: 30, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selection == category
                                      ? Color.accentColor.opacity(0.25)
                                      : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(selection == category
                                        ? Color.accentColor
                                        : Color.clear,
                                        lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help(category.label)
            }
        }
    }
}
