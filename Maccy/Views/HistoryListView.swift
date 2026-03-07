import Defaults
import SwiftUI
import UniformTypeIdentifiers

struct HistoryListView: View {
  @Binding var searchQuery: String
  @FocusState.Binding var searchFocused: Bool

  @State private var draggingPinnedItemID: UUID?
  @State private var activePinnedDropIndex: Int?
  @State private var pinnedItemHeights: [UUID: CGFloat] = [:]

  @Environment(AppState.self) private var appState
  @Environment(ModifierFlags.self) private var modifierFlags
  @Environment(\.scenePhase) private var scenePhase

  @Default(.pinTo) private var pinTo
  @Default(.previewDelay) private var previewDelay

  private var pinnedItems: [HistoryItemDecorator] {
    appState.history.pinnedItems.filter(\.isVisible)
  }
  private var unpinnedItems: [HistoryItemDecorator] {
    appState.history.unpinnedItems.filter(\.isVisible)
  }
  private var showPinsSeparator: Bool {
    !pinnedItems.isEmpty && !unpinnedItems.isEmpty && appState.history.searchQuery.isEmpty
  }
  private var canReorderPinnedItems: Bool {
    pinnedItems.count > 1 && appState.history.searchQuery.isEmpty
  }

  var body: some View {
    Group {
      if pinTo == .top {
        pinnedSection(showSeparatorAfterItems: true)
      }

      ScrollView {
        ScrollViewReader { proxy in
          LazyVStack(spacing: 0) {
            ForEach(unpinnedItems) { item in
              HistoryItemView(item: item)
            }
          }
          .task(id: appState.scrollTarget) {
            guard appState.scrollTarget != nil else { return }

            try? await Task.sleep(for: .milliseconds(10))
            guard !Task.isCancelled else { return }

            if let selection = appState.scrollTarget {
              proxy.scrollTo(selection)
              appState.scrollTarget = nil
            }
          }
          .onChange(of: scenePhase) {
            if scenePhase == .active {
              searchFocused = true
              HistoryItemDecorator.previewThrottler.minimumDelay = Double(previewDelay) / 1000
              HistoryItemDecorator.previewThrottler.cancel()
              appState.isKeyboardNavigating = true
              appState.selection = appState.history.unpinnedItems.first?.id ?? appState.history.pinnedItems.first?.id
            } else {
              modifierFlags.flags = []
              appState.isKeyboardNavigating = true
              clearPinnedDragState()
            }
          }
          // Calculate the total height inside a scroll view.
          .background {
            GeometryReader { geo in
              Color.clear
                .task(id: geo.size.height) {
                  try? await Task.sleep(for: .milliseconds(10))
                  guard !Task.isCancelled else { return }

                  appState.popup.resize(height: geo.size.height)
                }
            }
          }
        }
        .contentMargins(.leading, 10, for: .scrollIndicators)
      }

      if pinTo == .bottom {
        pinnedSection(showSeparatorAfterItems: false)
      }
    }
    .onChange(of: draggingPinnedItemID) {
      if draggingPinnedItemID == nil {
        activePinnedDropIndex = nil
      }
    }
    .onChange(of: canReorderPinnedItems) {
      if !canReorderPinnedItems {
        clearPinnedDragState()
      }
    }
    .onChange(of: pinnedItems.map(\.id)) {
      let pinnedItemIDs = Set(pinnedItems.map(\.id))
      if let draggingPinnedItemID, !pinnedItemIDs.contains(draggingPinnedItemID) {
        clearPinnedDragState()
      } else if let activePinnedDropIndex, activePinnedDropIndex > pinnedItems.count {
        self.activePinnedDropIndex = nil
      }
    }
  }

  @ViewBuilder
  private func pinnedSection(showSeparatorAfterItems: Bool) -> some View {
    LazyVStack(spacing: 0) {
      if !showSeparatorAfterItems, showPinsSeparator {
        pinsSeparator
      }

      ForEach(Array(pinnedItems.enumerated()), id: \.element.id) { index, item in
        pinnedItemView(item, pinnedIndex: index)
      }

      if showSeparatorAfterItems, showPinsSeparator {
        pinsSeparator
      }
    }
    .background {
      GeometryReader { geo in
        Color.clear
          .task(id: geo.size.height) {
            appState.popup.pinnedItemsHeight = geo.size.height
          }
      }
    }
    .overlay(alignment: .top) {
      if canReorderPinnedItems {
        pinnedBoundaryDropZone(pinnedIndex: 0)
      }
    }
    .overlay(alignment: .bottom) {
      if canReorderPinnedItems {
        pinnedBoundaryDropZone(pinnedIndex: pinnedItems.count)
      }
    }
  }

  @ViewBuilder
  private func pinnedItemView(_ item: HistoryItemDecorator, pinnedIndex: Int) -> some View {
    let rowHeight = max(pinnedItemHeights[item.id] ?? 0, Popup.itemHeight)
    let isLastPinnedItem = pinnedIndex == pinnedItems.count - 1

    if canReorderPinnedItems {
      HistoryItemView(item: item)
        .contentShape(Rectangle())
        .background {
          GeometryReader { geo in
            Color.clear
              .task(id: geo.size.height) {
                let height = geo.size.height
                if pinnedItemHeights[item.id] != height {
                  pinnedItemHeights[item.id] = height
                }
              }
          }
        }
        .overlay(alignment: .top) {
          pinnedInsertionIndicator(
            isVisible: draggingPinnedItemID != nil && activePinnedDropIndex == pinnedIndex
          )
        }
        .overlay(alignment: .bottom) {
          pinnedInsertionIndicator(
            isVisible: draggingPinnedItemID != nil
              && isLastPinnedItem
              && activePinnedDropIndex == pinnedItems.count
          )
        }
        .onDrag {
          activePinnedDropIndex = nil
          draggingPinnedItemID = item.id
          return NSItemProvider(object: item.id.uuidString as NSString)
        }
        .onDrop(
          of: [UTType.text],
          delegate: HistoryPinnedRowDropDelegate(
            targetPinnedIndex: pinnedIndex,
            maxPinnedIndex: pinnedItems.count,
            rowHeight: rowHeight,
            history: appState.history,
            draggingPinnedItemID: $draggingPinnedItemID,
            activePinnedDropIndex: $activePinnedDropIndex
          )
        )
    } else {
      HistoryItemView(item: item)
    }
  }

  private var pinsSeparator: some View {
    Divider()
      .padding(.horizontal, 10)
      .padding(.vertical, 3)
  }

  private func pinnedInsertionIndicator(isVisible: Bool) -> some View {
    Rectangle()
      .fill(Color.accentColor.opacity(0.9))
      .frame(height: 3)
      .padding(.horizontal, 10)
      .opacity(isVisible ? 1 : 0)
      .allowsHitTesting(false)
  }

  private func pinnedBoundaryDropZone(pinnedIndex: Int) -> some View {
    Color.clear
      .frame(height: 12)
      .contentShape(Rectangle())
      .onDrop(
        of: [UTType.text],
        delegate: HistoryPinnedBoundaryDropDelegate(
          targetPinnedIndex: pinnedIndex,
          history: appState.history,
          draggingPinnedItemID: $draggingPinnedItemID,
          activePinnedDropIndex: $activePinnedDropIndex
        )
      )
  }

  private func clearPinnedDragState() {
    draggingPinnedItemID = nil
    activePinnedDropIndex = nil
  }
}

@MainActor
private struct HistoryPinnedRowDropDelegate: DropDelegate {
  let targetPinnedIndex: Int
  let maxPinnedIndex: Int
  let rowHeight: CGFloat
  let history: History
  @Binding var draggingPinnedItemID: UUID?
  @Binding var activePinnedDropIndex: Int?

  func validateDrop(info: DropInfo) -> Bool {
    draggingPinnedItemID != nil && history.searchQuery.isEmpty
  }

  func dropEntered(info: DropInfo) {
    updateDropTarget(with: info)
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    guard draggingPinnedItemID != nil else {
      activePinnedDropIndex = nil
      return nil
    }

    updateDropTarget(with: info)
    return DropProposal(operation: .move)
  }

  func dropExited(info: DropInfo) {
    let candidateIndexes = [targetPinnedIndex, min(targetPinnedIndex + 1, maxPinnedIndex)]
    if let activePinnedDropIndex, candidateIndexes.contains(activePinnedDropIndex) {
      self.activePinnedDropIndex = nil
    }
  }

  private func updateDropTarget(with info: DropInfo) {
    activePinnedDropIndex = pinnedDropIndex(for: info)
  }

  private func pinnedDropIndex(for info: DropInfo) -> Int {
    guard rowHeight > 0 else {
      return min(targetPinnedIndex + 1, maxPinnedIndex)
    }

    return info.location.y < rowHeight / 2 ? targetPinnedIndex : min(targetPinnedIndex + 1, maxPinnedIndex)
  }

  func performDrop(info: DropInfo) -> Bool {
    guard let draggingPinnedItemID else {
      activePinnedDropIndex = nil
      self.draggingPinnedItemID = nil
      return false
    }

    history.movePinned(itemWithID: draggingPinnedItemID, toPinnedIndex: pinnedDropIndex(for: info))

    DispatchQueue.main.async {
      activePinnedDropIndex = nil
      self.draggingPinnedItemID = nil
    }
    return true
  }
}

@MainActor
private struct HistoryPinnedBoundaryDropDelegate: DropDelegate {
  let targetPinnedIndex: Int
  let history: History
  @Binding var draggingPinnedItemID: UUID?
  @Binding var activePinnedDropIndex: Int?

  func validateDrop(info: DropInfo) -> Bool {
    draggingPinnedItemID != nil && history.searchQuery.isEmpty
  }

  func dropEntered(info: DropInfo) {
    activePinnedDropIndex = targetPinnedIndex
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    guard draggingPinnedItemID != nil else {
      activePinnedDropIndex = nil
      return nil
    }

    activePinnedDropIndex = targetPinnedIndex
    return DropProposal(operation: .move)
  }

  func dropExited(info: DropInfo) {
    if activePinnedDropIndex == targetPinnedIndex {
      activePinnedDropIndex = nil
    }
  }

  func performDrop(info: DropInfo) -> Bool {
    guard let draggingPinnedItemID else {
      activePinnedDropIndex = nil
      self.draggingPinnedItemID = nil
      return false
    }

    history.movePinned(itemWithID: draggingPinnedItemID, toPinnedIndex: targetPinnedIndex)

    DispatchQueue.main.async {
      activePinnedDropIndex = nil
      self.draggingPinnedItemID = nil
    }
    return true
  }
}
