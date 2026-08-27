import Foundation

public enum StoreError: Error, Equatable {
    case invalidAmount
    case invalidExchangeRate
    case missingUSDExchangeRate
    case persistenceFailed
    case noBackupAvailable
    case recoveryRequired
}

public enum StoreStatus: Equatable {
    case healthy
    case recoveredFromBackup
    case unrecoverableData
}
