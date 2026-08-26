import Foundation

public struct GoalProgress {
    public let totalMXN: Decimal
    public let goalMXN: Decimal?

    public init(totalMXN: Decimal, goalMXN: Decimal?) {
        self.totalMXN = totalMXN
        self.goalMXN = goalMXN
    }

    private var rawFraction: Double? {
        guard let goalMXN, goalMXN > 0 else { return nil }
        let ratio = totalMXN / goalMXN
        return NSDecimalNumber(decimal: ratio).doubleValue
    }

    /// Capped to 1.0 — safe to feed directly into `ProgressView(value:)`.
    public var fraction: Double? {
        guard let rawFraction else { return nil }
        return min(rawFraction, 1.0)
    }

    /// Not capped — can exceed "100%" when the goal was surpassed.
    public var percentText: String? {
        guard let rawFraction else { return nil }
        let percent = Int((rawFraction * 100).rounded())
        return "\(percent)%"
    }
}
