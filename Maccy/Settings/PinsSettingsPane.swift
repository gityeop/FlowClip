import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct PinPickerView: View {
  @Bindable var item: HistoryItem
  var availablePins: [String]

  var body: some View {
    if let pin = item.pin {
      // Ensure unique pins for ForEach
      let uniquePins = Array(Set(availablePins + [pin])).sorted()
      Picker("", selection: $item.pin) {
        ForEach(uniquePins, id: \.self) { pin in
          Text(pin)
            .tag(pin as String?)
        }
      }
      .controlSize(.small)
      .labelsHidden()
    }
  }
}

struct PinTitleView: View {
  @Bindable var item: HistoryItem

  var body: some View {
    TextField("", text: $item.title)
  }
}

struct PinValueView: View {
  @Bindable var item: HistoryItem
  @State private var editableValue: String
  @State private var isTextContent: Bool
  @State private var isRichText: Bool
  @FocusState private var isEditing: Bool
  @State private var showWarningPopover: Bool = false

  init(item: HistoryItem) {
    self.item = item
    self._editableValue = State(initialValue: item.previewableText)

    // Check if this item has editable text content
    let hasPlainText = item.text != nil
    let hasImage = item.image != nil
    let hasFileURLs = !item.fileURLs.isEmpty
    let hasRichText = item.rtf != nil || item.html != nil

    // Consider it text content only if it has plain text and doesn't have images or file URLs
    self._isTextContent = State(initialValue: hasPlainText && !hasImage && !hasFileURLs)
    self._isRichText = State(initialValue: hasRichText && !hasImage && !hasFileURLs)
  }

  var body: some View {
    Group {
      if isTextContent || isRichText {
        ZStack(alignment: .trailing) {
          TextField("", text: $editableValue)
            .focused($isEditing)
            .onSubmit {
              updateItemContent()
            }
            .onChange(of: editableValue) { _, _ in
              updateItemContent()
            }
            .padding(.trailing, isRichText ? 40 : 0) // increased space for icon

          if isRichText && isEditing {
            HStack(spacing: 0) {
              Spacer(minLength: 0)
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .help(Text("RichTextEditWarning", tableName: "PinsSettings"))
              Spacer().frame(width: 4)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .padding(.trailing, 4)
          }
        }
      } else {
        // Non-editable display for non-text content
        Text("ContentIsNotText", tableName: "PinsSettings")
          .foregroundStyle(.secondary)
          .italic()
      }
    }
  }

  private func updateItemContent() {
    // Only update if we're dealing with text or rich text content
    guard isTextContent || isRichText else { return }

    // Remove all non-plain-text content
    let stringType = NSPasteboard.PasteboardType.string.rawValue
    item.contents.removeAll { $0.type != stringType }

    // Update or add the plain text content
    if let index = item.contents.firstIndex(where: { $0.type == stringType }) {
      if let data = editableValue.data(using: .utf8) {
        item.contents[index].value = data
      }
    } else {
      if let data = editableValue.data(using: .utf8) {
        let newContent = HistoryItemContent(type: stringType, value: data)
        item.contents.append(newContent)
      }
    }
    // We don't automatically update title here since we want to preserve
    // OCR-extracted titles for images and other non-text content
  }
}

struct PinsSettingsPane: View {
  @Environment(AppState.self) private var appState

  @State private var availablePins: [String] = []
  @State private var selection: UUID?
  @State private var draggingPinnedItemID: UUID?
  @State private var activePinnedDropIndex: Int?
  @State private var rowHeights: [UUID: CGFloat] = [:]

  private var pinnedItems: [HistoryItemDecorator] {
    appState.history.pinnedItems
  }

  private var canReorderPinnedItems: Bool {
    pinnedItems.count > 1
  }

  var body: some View {
    VStack(alignment: .leading) {
      Table(pinnedItems, selection: $selection) {
        TableColumn("") { item in
          PinReorderHandleView(
            itemID: item.id,
            canReorder: canReorderPinnedItems,
            selection: $selection,
            draggingPinnedItemID: $draggingPinnedItemID,
            activePinnedDropIndex: $activePinnedDropIndex
          )
          .background {
            GeometryReader { geo in
              Color.clear
                .task(id: geo.size.height) {
                  let height = geo.size.height
                  if rowHeights[item.id] != height {
                    rowHeights[item.id] = height
                  }
                }
            }
          }
          .modifier(
            PinsSettingsPinnedDropTargetModifier(
              pinnedIndex: pinnedIndex(for: item),
              pinnedCount: pinnedItems.count,
              rowHeight: rowHeights[item.id] ?? 0,
              draggingPinnedItemID: $draggingPinnedItemID,
              activePinnedDropIndex: $activePinnedDropIndex
            ) { sourceID, targetPinnedIndex in
              appState.history.movePinned(itemWithID: sourceID, toPinnedIndex: targetPinnedIndex)
            }
          )
        }
        .width(24)

        TableColumn(Text("Key", tableName: "PinsSettings")) { item in
          PinPickerView(item: item.item, availablePins: availablePins)
            .modifier(
              PinsSettingsPinnedDropTargetModifier(
                pinnedIndex: pinnedIndex(for: item),
                pinnedCount: pinnedItems.count,
                rowHeight: rowHeights[item.id] ?? 0,
                draggingPinnedItemID: $draggingPinnedItemID,
                activePinnedDropIndex: $activePinnedDropIndex
              ) { sourceID, targetPinnedIndex in
                appState.history.movePinned(itemWithID: sourceID, toPinnedIndex: targetPinnedIndex)
              }
            )
            .onChange(of: item.item.pin) {
              availablePins = HistoryItem.availablePins
            }
        }
        .width(60)

        TableColumn(Text("Alias", tableName: "PinsSettings")) { item in
          PinTitleView(item: item.item)
            .modifier(
              PinsSettingsPinnedDropTargetModifier(
                pinnedIndex: pinnedIndex(for: item),
                pinnedCount: pinnedItems.count,
                rowHeight: rowHeights[item.id] ?? 0,
                draggingPinnedItemID: $draggingPinnedItemID,
                activePinnedDropIndex: $activePinnedDropIndex
              ) { sourceID, targetPinnedIndex in
                appState.history.movePinned(itemWithID: sourceID, toPinnedIndex: targetPinnedIndex)
              }
            )
        }

        TableColumn(Text("Content", tableName: "PinsSettings")) { item in
          PinValueView(item: item.item)
            .modifier(
              PinsSettingsPinnedDropTargetModifier(
                pinnedIndex: pinnedIndex(for: item),
                pinnedCount: pinnedItems.count,
                rowHeight: rowHeights[item.id] ?? 0,
                draggingPinnedItemID: $draggingPinnedItemID,
                activePinnedDropIndex: $activePinnedDropIndex
              ) { sourceID, targetPinnedIndex in
                appState.history.movePinned(itemWithID: sourceID, toPinnedIndex: targetPinnedIndex)
              }
            )
        }
      }
      .onAppear {
        availablePins = HistoryItem.availablePins
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
        availablePins = HistoryItem.availablePins
        rowHeights = rowHeights.filter { pinnedItemIDs.contains($0.key) }

        if let selection, !pinnedItemIDs.contains(selection) {
          self.selection = nil
        }

        if let draggingPinnedItemID, !pinnedItemIDs.contains(draggingPinnedItemID) {
          clearPinnedDragState()
        } else if let activePinnedDropIndex, activePinnedDropIndex > pinnedItems.count {
          self.activePinnedDropIndex = nil
        }
      }
      .onDeleteCommand {
        guard let selection,
              let item = pinnedItems.first(where: { $0.id == selection }) else {
          return
        }

        appState.history.delete(item)
      }

      Text("PinCustomizationDescription", tableName: "PinsSettings")
        .foregroundStyle(.gray)
        .controlSize(.small)
    }
    .frame(minWidth: 500, minHeight: 400)
    .padding()
  }
}

#Preview {
  return PinsSettingsPane()
    .environment(AppState.shared)
    .environment(\.locale, .init(identifier: "en"))
    .modelContainer(Storage.shared.container)
}

private extension PinsSettingsPane {
  func pinnedIndex(for item: HistoryItemDecorator) -> Int {
    pinnedItems.firstIndex(where: { $0.id == item.id }) ?? 0
  }

  func clearPinnedDragState() {
    draggingPinnedItemID = nil
    activePinnedDropIndex = nil
  }
}

private struct PinReorderHandleView: View {
  let itemID: UUID
  let canReorder: Bool
  @Binding var selection: UUID?
  @Binding var draggingPinnedItemID: UUID?
  @Binding var activePinnedDropIndex: Int?

  var body: some View {
    Group {
      if canReorder {
        handle
          .onDrag {
            selection = itemID
            activePinnedDropIndex = nil
            draggingPinnedItemID = itemID
            return NSItemProvider(object: itemID.uuidString as NSString)
          }
      } else {
        handle
      }
    }
  }

  private var handle: some View {
    Image(systemName: "line.3.horizontal")
      .foregroundStyle(canReorder ? .secondary : .tertiary)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(Rectangle())
      .help(Text("ReorderPin", tableName: "PinsSettings"))
      .accessibilityLabel(Text("ReorderPin", tableName: "PinsSettings"))
  }
}

private struct PinsSettingsPinnedDropTargetModifier: ViewModifier {
  let pinnedIndex: Int
  let pinnedCount: Int
  let rowHeight: CGFloat
  @Binding var draggingPinnedItemID: UUID?
  @Binding var activePinnedDropIndex: Int?
  let movePinnedItem: (UUID, Int) -> Void

  func body(content: Content) -> some View {
    content
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      .overlay(alignment: .top) {
        pinnedInsertionIndicator(isVisible: draggingPinnedItemID != nil && activePinnedDropIndex == pinnedIndex)
      }
      .overlay(alignment: .bottom) {
        pinnedInsertionIndicator(
          isVisible: draggingPinnedItemID != nil
            && pinnedIndex == pinnedCount - 1
            && activePinnedDropIndex == pinnedCount
        )
      }
      .onDrop(
        of: [UTType.text],
        delegate: PinsSettingsPinnedDropDelegate(
          targetPinnedIndex: pinnedIndex,
          maxPinnedIndex: pinnedCount,
          rowHeight: rowHeight,
          movePinnedItem: movePinnedItem,
          draggingPinnedItemID: $draggingPinnedItemID,
          activePinnedDropIndex: $activePinnedDropIndex
        )
      )
  }

  private func pinnedInsertionIndicator(isVisible: Bool) -> some View {
    Rectangle()
      .fill(Color.accentColor.opacity(0.9))
      .frame(height: 3)
      .opacity(isVisible ? 1 : 0)
      .allowsHitTesting(false)
  }
}

@MainActor
private struct PinsSettingsPinnedDropDelegate: DropDelegate {
  let targetPinnedIndex: Int
  let maxPinnedIndex: Int
  let rowHeight: CGFloat
  let movePinnedItem: (UUID, Int) -> Void
  @Binding var draggingPinnedItemID: UUID?
  @Binding var activePinnedDropIndex: Int?

  func validateDrop(info: DropInfo) -> Bool {
    draggingPinnedItemID != nil
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

  func performDrop(info: DropInfo) -> Bool {
    guard let draggingPinnedItemID else {
      activePinnedDropIndex = nil
      self.draggingPinnedItemID = nil
      return false
    }

    movePinnedItem(draggingPinnedItemID, pinnedDropIndex(for: info))

    DispatchQueue.main.async {
      activePinnedDropIndex = nil
      self.draggingPinnedItemID = nil
    }
    return true
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
}
