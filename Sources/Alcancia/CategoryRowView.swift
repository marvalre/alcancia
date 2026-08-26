// Sources/Alcancia/CategoryRowView.swift
import SwiftUI
import AlcanciaCore

/// Las ocho categorías en una fila de emojis. Elegir es un clic, no un menú
/// desplegable — la diferencia entre capturar en tres segundos o en diez.
struct CategoryRowView: View {
    // Calificado explícitamente: en este SDK, objc/runtime.h también expone un
    // tipo `Category` a nivel global, y este archivo importa SwiftUI (que
    // arrastra AppKit) junto con AlcanciaCore — sin calificar, el nombre queda
    // ambiguo y el build falla.
    @Binding var selection: AlcanciaCore.Category

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AlcanciaCore.Category.allCases) { category in
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
