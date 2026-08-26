import Foundation
import ServiceManagement

enum LoginItemManager {
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("Alcancía: no se pudo cambiar el inicio automático: \(error)")
        }
    }
}
