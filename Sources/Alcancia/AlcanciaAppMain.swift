import SwiftUI
import AlcanciaCore

@main
struct AlcanciaAppMain: App {
    @StateObject private var store = AlcanciaStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(store: store)
        } label: {
            Text(store.menuBarSummary)
        }
        .menuBarExtraStyle(.window)
    }
}
