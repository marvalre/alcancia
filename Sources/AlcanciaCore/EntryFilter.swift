import Foundation

public struct EntryFilter: Equatable, Sendable {
    public var query: String
    public var kind: EntryKind?
    public var category: ExpenseCategory?
    public var business: Bool?

    public init(
        query: String = "",
        kind: EntryKind? = nil,
        category: ExpenseCategory? = nil,
        business: Bool? = nil
    ) {
        self.query = query
        self.kind = kind
        self.category = category
        self.business = business
    }

    public func apply(to entries: [Entry]) -> [Entry] {
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        return entries.filter { entry in
            if !normalizedQuery.isEmpty {
                guard let note = entry.note?.folding(
                    options: [.caseInsensitive, .diacriticInsensitive],
                    locale: .current
                ), note.contains(normalizedQuery)
                else { return false }
            }
            if let kind, entry.kind != kind { return false }
            if let category, entry.category != category { return false }
            if let business {
                guard entry.kind == .expense, entry.isBusiness == business else { return false }
            }
            return true
        }
    }
}
