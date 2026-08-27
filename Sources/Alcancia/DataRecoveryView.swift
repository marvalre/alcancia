import AppKit
import SwiftUI
import AlcanciaCore

struct DataRecoveryView: View {
    @ObservedObject var store: AlcanciaStore
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 32))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text("Tus datos necesitan recuperación")
                .font(.title3.bold())

            Text("Alcancía no pudo leer el archivo principal y lo dejó intacto. No se guardará nada encima hasta recuperar un respaldo.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("Recuperar último respaldo") {
                switch store.restoreLatestBackup() {
                case .success: message = "Respaldo recuperado correctamente."
                case .failure: message = "No se encontró un respaldo válido. El archivo original sigue intacto."
                }
            }
            .buttonStyle(.borderedProminent)

            if let message {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Button("Salir de Alcancía") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
        }
        .padding(24)
    }
}
