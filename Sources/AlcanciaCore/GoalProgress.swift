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
    /// Clamped to a safe ceiling so a pathological goal can't crash the app.
    public var percentText: String? {
        guard let rawFraction, rawFraction.isFinite else { return nil }
        let scaled = min((rawFraction * 100).rounded(), 999_999_999_999)
        return "\(Int(scaled))%"
    }
}
