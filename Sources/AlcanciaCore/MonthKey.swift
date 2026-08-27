import Foundation

/// Clave de mes independiente de zona horaria, estable para presupuestos y recurrentes.
public struct MonthKey: Codable, Hashable, Comparable, Equatable {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) {
        precondition((1...12).contains(month), "El mes debe estar entre 1 y 12")
        self.year = year
        self.month = month
    }

    public init(date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) {
        let components = calendar.dateComponents([.year, .month], from: date)
        self.init(year: components.year!, month: components.month!)
    }

    public static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}
