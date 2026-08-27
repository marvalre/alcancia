import Foundation

public enum StoreError: Error, Equatable {
    case invalidAmount
    case invalidExchangeRate
    case missingUSDExchangeRate
    case persistenceFailed
    case noBackupAvailable
    case recoveryRequired
    /// El movimiento que se quería editar/restaurar ya no existe — p. ej. se
    /// borró en otra parte de la app antes de que un "deshacer" pendiente se
    /// disparara. Antes esto reportaba éxito sin escribir nada.
    case entryNotFound
    /// Se intentó restaurar un movimiento cuyo id ya está presente.
    case entryAlreadyExists
}

public enum StoreStatus: Equatable {
    case healthy
    case recoveredFromBackup
    case unrecoverableData
}
