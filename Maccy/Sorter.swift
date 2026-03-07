import AppKit
import Defaults

// swiftlint:disable identifier_name
// swiftlint:disable type_name
class Sorter {
  enum By: String, CaseIterable, Identifiable, CustomStringConvertible, Defaults.Serializable {
    case lastCopiedAt
    case firstCopiedAt
    case numberOfCopies

    var id: Self { self }

    var description: String {
      switch self {
      case .lastCopiedAt:
        return NSLocalizedString("LastCopiedAt", tableName: "StorageSettings", comment: "")
      case .firstCopiedAt:
        return NSLocalizedString("FirstCopiedAt", tableName: "StorageSettings", comment: "")
      case .numberOfCopies:
        return NSLocalizedString("NumberOfCopies", tableName: "StorageSettings", comment: "")
      }
    }
  }

  func sort(_ items: [HistoryItem], by: By = Defaults[.sortBy]) -> [HistoryItem] {
    return items.sorted { lhs, rhs in
      if let pinnedOrder = byPinned(lhs, rhs, by) {
        return pinnedOrder
      }

      return bySortingAlgorithm(lhs, rhs, by)
    }
  }

  private func bySortingAlgorithm(_ lhs: HistoryItem, _ rhs: HistoryItem, _ by: By) -> Bool {
    switch by {
    case .firstCopiedAt:
      return lhs.firstCopiedAt > rhs.firstCopiedAt
    case .numberOfCopies:
      return lhs.numberOfCopies > rhs.numberOfCopies
    default:
      return lhs.lastCopiedAt > rhs.lastCopiedAt
    }
  }

  private func byPinned(_ lhs: HistoryItem, _ rhs: HistoryItem, _ by: By) -> Bool? {
    switch (lhs.pin != nil, rhs.pin != nil) {
    case (true, false):
      return Defaults[.pinTo] == .top
    case (false, true):
      return Defaults[.pinTo] == .bottom
    case (true, true):
      if let lhsPinOrder = lhs.pinOrder, let rhsPinOrder = rhs.pinOrder, lhsPinOrder != rhsPinOrder {
        return lhsPinOrder < rhsPinOrder
      }
      if lhs.pinOrder != nil, rhs.pinOrder == nil {
        return true
      }
      if lhs.pinOrder == nil, rhs.pinOrder != nil {
        return false
      }
      return bySortingAlgorithm(lhs, rhs, by)
    case (false, false):
      return nil
    }
  }
}
// swiftlint:enable identifier_name
// swiftlint:enable type_name
