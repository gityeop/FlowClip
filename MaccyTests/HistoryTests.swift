import XCTest
import AppKit
import Defaults
import SwiftUI
@testable import FlowClip

class HistoryTests: XCTestCase {
  let savedSize = Defaults[.size]
  let savedSortBy = Defaults[.sortBy]
  let savedPinTo = Defaults[.pinTo]
  let history = History.shared

  @MainActor
  override func setUp() {
    super.setUp()
    history.clearAll()
    Defaults[.size] = 10
    Defaults[.sortBy] = .firstCopiedAt
    Defaults[.pinTo] = .top
  }

  @MainActor
  override func tearDown() {
    super.tearDown()
    Defaults[.size] = savedSize
    Defaults[.sortBy] = savedSortBy
    Defaults[.pinTo] = savedPinTo
  }

  @MainActor
  func testDefaultIsEmpty() {
    XCTAssertEqual(history.items, [])
  }

  @MainActor
  func testAdding() {
    let first = history.add(historyItem("foo"))
    let second = history.add(historyItem("bar"))
    XCTAssertEqual(history.items, [second, first])
  }

  @MainActor
  func testAddingSame() {
    let first = historyItem("foo")
    first.title = "xyz"
    first.application = "iTerm.app"
    let firstDecorator = history.add(first)
    first.pin = "f"

    let secondDecorator = history.add(historyItem("bar"))

    let third = historyItem("foo")
    third.application = "Xcode.app"
    history.add(third)

    XCTAssertEqual(history.items, [firstDecorator, secondDecorator])
    XCTAssertTrue(history.items[0].item.lastCopiedAt > history.items[0].item.firstCopiedAt)
    // TODO: This works in reality but fails in tests?!
    // XCTAssertEqual(history.items[0].item.numberOfCopies, 2)
    XCTAssertEqual(history.items[0].item.pin, "f")
    XCTAssertEqual(history.items[0].item.title, "xyz")
    XCTAssertEqual(history.items[0].item.application, "iTerm.app")
  }

  @MainActor
  func testAddingItemThatIsSupersededByExisting() {
    let firstContents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: "one".data(using: .utf8)!
      ),
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.rtf.rawValue,
        value: "two".data(using: .utf8)!
      )
    ]
    let firstItem = HistoryItem()
    Storage.shared.context.insert(firstItem)
    firstItem.application = "Maccy.app"
    firstItem.contents = firstContents
    firstItem.title = firstItem.generateTitle()
    history.add(firstItem)

    let secondContents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: "one".data(using: .utf8)!
      )
    ]
    let secondItem = HistoryItem()
    Storage.shared.context.insert(secondItem)
    secondItem.application = "Maccy.app"
    secondItem.contents = secondContents
    secondItem.title = secondItem.generateTitle()
    let second = history.add(secondItem)

    XCTAssertEqual(history.items, [second])
    XCTAssertEqual(Set(history.items[0].item.contents), Set(firstContents))
  }

  @MainActor
  func testAddingItemWithDifferentModifiedType() {
    let firstContents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: "one".data(using: .utf8)!
      ),
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.modified.rawValue,
        value: "1".data(using: .utf8)!
      )
    ]
    let firstItem = HistoryItem()
    Storage.shared.context.insert(firstItem)
    firstItem.contents = firstContents
    history.add(firstItem)

    let secondContents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: "one".data(using: .utf8)!
      ),
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.modified.rawValue,
        value: "2".data(using: .utf8)!
      )
    ]
    let secondItem = HistoryItem()
    Storage.shared.context.insert(secondItem)
    secondItem.contents = secondContents
    let second = history.add(secondItem)

    XCTAssertEqual(history.items, [second])
    XCTAssertEqual(Set(history.items[0].item.contents), Set(firstContents))
  }

  @MainActor
  func testAddingItemFromMaccy() {
    let firstContents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: "one".data(using: .utf8)
      )
    ]
    let first = HistoryItem()
    Storage.shared.context.insert(first)
    first.application = "Xcode.app"
    first.contents = firstContents
    history.add(first)

    let secondContents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: "one".data(using: .utf8)
      ),
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.fromMaccy.rawValue,
        value: "".data(using: .utf8)
      )
    ]
    let second = HistoryItem()
    Storage.shared.context.insert(second)
    second.application = "Maccy.app"
    second.contents = secondContents
    let secondDecorator = history.add(second)

    XCTAssertEqual(history.items, [secondDecorator])
    XCTAssertEqual(history.items[0].item.application, "Xcode.app")
    XCTAssertEqual(Set(history.items[0].item.contents), Set(firstContents))
  }

  @MainActor
  func testModifiedAfterCopying() {
    history.add(historyItem("foo"))

    let modifiedItem = historyItem("bar")
    modifiedItem.contents.append(HistoryItemContent(
      type: NSPasteboard.PasteboardType.modified.rawValue,
      value: String(Clipboard.shared.changeCount).data(using: .utf8)
    ))
    let modifiedItemDecorator = history.add(modifiedItem)

    XCTAssertEqual(history.items, [modifiedItemDecorator])
    XCTAssertEqual(history.items[0].text, "bar")
  }

  @MainActor
  func testClearingUnpinned() {
    let pinned = history.add(historyItem("foo"))
    pinned.togglePin()
    history.add(historyItem("bar"))
    history.clear()
    XCTAssertEqual(history.items, [pinned])
  }

  @MainActor
  func testClearingAll() {
    history.add(historyItem("foo"))
    history.clear()
    XCTAssertEqual(history.items, [])
  }

  @MainActor
  func testMovePinnedToFirstPinnedIndexReordersPinnedSectionOnly() {
    let firstPinned = history.add(historyItem("first pinned"))
    let secondPinned = history.add(historyItem("second pinned"))
    history.add(historyItem("regular"))

    history.togglePin(firstPinned)
    history.togglePin(secondPinned)
    history.movePinned(itemWithID: secondPinned.id, toPinnedIndex: 0)

    XCTAssertEqual(history.items.compactMap { $0.item.text }, ["second pinned", "first pinned", "regular"])
    XCTAssertEqual(firstPinned.item.pinOrder, 1)
    XCTAssertEqual(secondPinned.item.pinOrder, 0)
  }

  @MainActor
  func testMovePinnedToLastPinnedSlotMovesItemToLastPinnedPosition() {
    let firstPinned = history.add(historyItem("first pinned"))
    let secondPinned = history.add(historyItem("second pinned"))
    let thirdPinned = history.add(historyItem("third pinned"))
    history.add(historyItem("regular"))

    history.togglePin(firstPinned)
    history.togglePin(secondPinned)
    history.togglePin(thirdPinned)
    history.movePinned(itemWithID: firstPinned.id, toPinnedIndex: 3)

    XCTAssertEqual(
      history.items.compactMap { $0.item.text },
      ["second pinned", "third pinned", "first pinned", "regular"]
    )
    XCTAssertEqual(secondPinned.item.pinOrder, 0)
    XCTAssertEqual(thirdPinned.item.pinOrder, 1)
    XCTAssertEqual(firstPinned.item.pinOrder, 2)
  }

  @MainActor
  func testMovePinnedDoesNothingForUnchangedPinnedSlots() {
    let firstPinned = history.add(historyItem("first pinned"))
    let secondPinned = history.add(historyItem("second pinned"))
    let thirdPinned = history.add(historyItem("third pinned"))

    history.togglePin(firstPinned)
    history.togglePin(secondPinned)
    history.togglePin(thirdPinned)

    history.movePinned(itemWithID: secondPinned.id, toPinnedIndex: 1)
    history.movePinned(itemWithID: secondPinned.id, toPinnedIndex: 2)

    XCTAssertEqual(
      history.items.compactMap { $0.item.text },
      ["first pinned", "second pinned", "third pinned"]
    )
    XCTAssertEqual(firstPinned.item.pinOrder, 0)
    XCTAssertEqual(secondPinned.item.pinOrder, 1)
    XCTAssertEqual(thirdPinned.item.pinOrder, 2)
  }

  @MainActor
  func testMovePinnedOrderPersistsAfterReload() async throws {
    let firstPinned = history.add(historyItem("first pinned"))
    let secondPinned = history.add(historyItem("second pinned"))
    let thirdPinned = history.add(historyItem("third pinned"))

    history.togglePin(firstPinned)
    history.togglePin(secondPinned)
    history.togglePin(thirdPinned)
    history.movePinned(itemWithID: thirdPinned.id, toPinnedIndex: 0)

    try await history.load()

    XCTAssertEqual(
      history.items.compactMap { $0.item.text },
      ["third pinned", "first pinned", "second pinned"]
    )
    XCTAssertEqual(history.items.compactMap(\.item.pinOrder), [0, 1, 2])
  }

  @MainActor
  func testMaxSize() {
    var items: [HistoryItemDecorator] = []
    for index in 0...10 {
      items.append(history.add(historyItem(String(index))))
    }

    XCTAssertEqual(history.items.count, 10)
    XCTAssertTrue(history.items.contains(items[10]))
    XCTAssertFalse(history.items.contains(items[0]))
  }

  @MainActor
  func testMaxSizeIgnoresPinned() {
    var items: [HistoryItemDecorator] = []

    let item = history.add(historyItem("0"))
    items.append(item)
    item.togglePin()

    for index in 1...11 {
      items.append(history.add(historyItem(String(index))))
    }

    XCTAssertEqual(history.items.count, 11)
    XCTAssertTrue(history.items.contains(items[10]))
    XCTAssertTrue(history.items.contains(items[0]))
    XCTAssertFalse(history.items.contains(items[1]))
  }

  @MainActor
  func testMaxSizeIsChanged() {
    var items: [HistoryItemDecorator] = []
    for index in 0...10 {
      items.append(history.add(historyItem(String(index))))
    }
    Defaults[.size] = 5
    history.add(historyItem("11"))

    XCTAssertEqual(history.items.count, 5)
    XCTAssertTrue(history.items.contains(items[10]))
    XCTAssertFalse(history.items.contains(items[5]))
  }

  @MainActor
  func testRemoving() {
    let foo = history.add(historyItem("foo"))
    let bar = history.add(historyItem("bar"))
    history.delete(foo)
    XCTAssertEqual(history.items, [bar])
  }

  @MainActor
  func testLoadMigratesImageTitleToRecognizedText() async throws {
    let image = try XCTUnwrap(NSImage(named: "NSBluetoothTemplate"))
    let item = historyItem(image)
    item.title = "old OCR text"
    try? Storage.shared.context.save()

    try await history.load()

    XCTAssertEqual(history.items[0].item.title, "")
    XCTAssertEqual(history.items[0].item.recognizedText, "old OCR text")
  }

  @MainActor
  private func historyItem(_ value: String) -> HistoryItem {
    let contents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: value.data(using: .utf8)
      )
    ]
    let item = HistoryItem()
    Storage.shared.context.insert(item)
    item.contents = contents
    item.numberOfCopies = 1
    item.title = item.generateTitle()

    return item
  }

  @MainActor
  private func historyItem(_ value: NSImage) -> HistoryItem {
    let contents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.tiff.rawValue,
        value: value.tiffRepresentation!
      )
    ]
    let item = HistoryItem()
    Storage.shared.context.insert(item)
    item.contents = contents
    item.numberOfCopies = 1

    return item
  }
}

class HistorySearchTests: XCTestCase {
  let savedSize = Defaults[.size]
  let savedSortBy = Defaults[.sortBy]
  let savedPinTo = Defaults[.pinTo]
  let history = History.shared

  override func setUpWithError() throws {
    try super.setUpWithError()
    runOnMainActor(description: "Reset history") { [self] in
      self.history.clearAll()
      self.history.searchQuery = ""
      AppState.shared.selection = nil
      Defaults[.size] = 10
      Defaults[.sortBy] = .firstCopiedAt
      Defaults[.pinTo] = .top
    }
  }

  override func tearDownWithError() throws {
    runOnMainActor(description: "Restore history") { [self] in
      self.history.clearAll()
      self.history.searchQuery = ""
      AppState.shared.selection = nil
      Defaults[.size] = self.savedSize
      Defaults[.sortBy] = self.savedSortBy
      Defaults[.pinTo] = self.savedPinTo
    }
    try super.tearDownWithError()
  }

  func testClearingSearchRestoresAllItemsImmediately() async {
    var filteredItemID: UUID!
    var restoredSelectionID: UUID!

    await MainActor.run {
      filteredItemID = history.add(historyItem("foo")).id
      restoredSelectionID = history.add(historyItem("bar")).id
      history.searchQuery = "foo"
    }

    waitForSearchThrottle()

    await MainActor.run {
      XCTAssertEqual(history.items.compactMap { $0.item.text }, ["foo"])
      XCTAssertEqual(AppState.shared.selection, filteredItemID)

      history.searchQuery = ""

      XCTAssertEqual(history.items.compactMap { $0.item.text }, ["bar", "foo"])
      XCTAssertEqual(AppState.shared.selection, restoredSelectionID)
    }
  }

  func testClearingSearchCancelsPendingThrottledSearch() async {
    var restoredSelectionID: UUID!

    await MainActor.run {
      _ = history.add(historyItem("foo"))
      restoredSelectionID = history.add(historyItem("bar")).id
      history.searchQuery = "foo"
      history.searchQuery = ""
    }

    waitForSearchThrottle()

    await MainActor.run {
      XCTAssertEqual(history.items.compactMap { $0.item.text }, ["bar", "foo"])
      XCTAssertEqual(AppState.shared.selection, restoredSelectionID)
    }
  }

  private func runOnMainActor(description: String, _ work: @escaping @MainActor () -> Void) {
    let expectation = expectation(description: description)

    Task { @MainActor in
      work()
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 2)
  }

  private func waitForSearchThrottle() {
    let expectation = expectation(description: "wait for throttled search")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1)
  }

  @MainActor
  private func historyItem(_ value: String) -> HistoryItem {
    let contents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: value.data(using: .utf8)
      )
    ]
    let item = HistoryItem()
    Storage.shared.context.insert(item)
    item.contents = contents
    item.numberOfCopies = 1
    item.title = item.generateTitle()

    return item
  }
}

class PopupSearchHeightTests: XCTestCase {
  let popup = AppState.shared.popup
  let history = History.shared
  let savedWindowSize = Defaults[.windowSize]
  let savedPopupPosition = Defaults[.popupPosition]

  override func setUpWithError() throws {
    try super.setUpWithError()
    runOnMainActor(description: "Reset popup") { [self] in
      popup.reset()
      popup.contentHeight = 0
      popup.headerHeight = 0
      popup.pinnedItemsHeight = 0
      popup.footerHeight = 0
      popup.height = 0
      history.searchQuery = ""
      Defaults[.windowSize] = NSSize(width: 450, height: 640)
      Defaults[.popupPosition] = .cursor
    }
  }

  override func tearDownWithError() throws {
    runOnMainActor(description: "Restore popup") { [self] in
      popup.reset()
      popup.contentHeight = 0
      popup.headerHeight = 0
      popup.pinnedItemsHeight = 0
      popup.footerHeight = 0
      popup.height = 0
      history.searchQuery = ""
      Defaults[.windowSize] = savedWindowSize
      Defaults[.popupPosition] = savedPopupPosition
    }
    try super.tearDownWithError()
  }

  func testEmptyQueryUsesSavedWindowHeight() {
    runOnMainActor(description: "Empty query uses saved height") { [self] in
      popup.resize(height: 900)

      XCTAssertEqual(popup.height, 640)
    }
  }

  func testClearingSearchRestoresSavedWindowHeight() {
    runOnMainActor(description: "Restore saved height") { [self] in
      history.searchQuery = "foo"
      popup.resize(height: 120)
      XCTAssertEqual(popup.height, expectedSearchHeight)

      history.searchQuery = ""

      XCTAssertEqual(popup.height, 640)
      popup.resize(height: 900)
      XCTAssertEqual(popup.height, 640)
    }
  }

  func testClearingSearchUsesLatestSavedWindowHeight() {
    runOnMainActor(description: "Restore latest saved height") { [self] in
      history.searchQuery = "foo"
      popup.resize(height: 120)
      Defaults[.windowSize] = NSSize(width: 450, height: 520)
      history.searchQuery = ""

      XCTAssertEqual(popup.height, 520)
    }
  }

  func testSearchingUsesFixedSessionHeight() {
    runOnMainActor(description: "Search uses a fixed session height") { [self] in
      history.searchQuery = "foo"
      popup.resize(height: 40)
      let searchHeight = popup.height

      popup.resize(height: 400)

      XCTAssertEqual(searchHeight, expectedSearchHeight)
      XCTAssertEqual(popup.height, searchHeight)
    }
  }

  func testSearchingFromStatusItemUsesFixedSessionHeight() {
    runOnMainActor(description: "Status item search uses a fixed session height") { [self] in
      Defaults[.popupPosition] = .statusItem
      history.searchQuery = "foo"
      popup.resize(height: 40)

      XCTAssertEqual(popup.height, expectedSearchHeight)
    }
  }

  func testSectionMeasurementsWaitForContentHeightCommit() {
    runOnMainActor(description: "Section measurements wait for content height") { [self] in
      let savedAppDelegate = AppState.shared.appDelegate
      let appDelegate = AppDelegate()
      let panel = CountingFloatingPanel(
        contentRect: NSRect(origin: .zero, size: Defaults[.windowSize]),
        identifier: "popup-measurement-commit-test",
        onClose: {}
      ) {
        ContentView()
      }
      panel.isPresented = true
      appDelegate.panel = panel
      AppState.shared.appDelegate = appDelegate

      history.searchQuery = "foo"
      popup.resize(height: 40)
      panel.requestedHeights.removeAll()

      popup.headerHeight = 10
      popup.pinnedItemsHeight = 20
      popup.footerHeight = 30

      XCTAssertTrue(panel.requestedHeights.isEmpty)

      popup.resize(height: 80)

      XCTAssertTrue(panel.requestedHeights.isEmpty)
      panel.isPresented = false
      AppState.shared.appDelegate = savedAppDelegate
    }
  }

  private var expectedSearchHeight: CGFloat {
    min(
      popup.headerHeight
        + (Popup.itemHeight * CGFloat(Popup.searchVisibleItemCount))
        + popup.footerHeight
        + (Popup.verticalPadding * 2),
      Defaults[.windowSize].height
    )
  }

  private func runOnMainActor(description: String, _ work: @escaping @MainActor () -> Void) {
    let expectation = expectation(description: description)

    Task { @MainActor in
      work()
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 2)
  }
}

private final class CountingFloatingPanel<Content: View>: FloatingPanel<Content> {
  var requestedHeights: [CGFloat] = []

  override func verticallyResize(to newHeight: CGFloat) {
    requestedHeights.append(newHeight)
  }
}

class FloatingPanelPersistenceTests: XCTestCase {
  let savedWindowSize = Defaults[.windowSize]
  let savedPopupPosition = Defaults[.popupPosition]

  override func setUpWithError() throws {
    try super.setUpWithError()
    Defaults[.popupPosition] = .cursor
  }

  override func tearDownWithError() throws {
    Defaults[.windowSize] = savedWindowSize
    Defaults[.popupPosition] = savedPopupPosition
    try super.tearDownWithError()
  }

  func testProgrammaticResizeDoesNotPersistWindowSize() {
    let expectation = expectation(description: "programmatic resize")

    Task { @MainActor in
      Defaults[.windowSize] = NSSize(width: 435, height: 423)
      let panel = FloatingPanel(
        contentRect: NSRect(origin: .zero, size: Defaults[.windowSize]),
        identifier: "floating-panel-persistence-test",
        onClose: {}
      ) {
        EmptyView()
      }

      panel.setFrame(NSRect(origin: .zero, size: NSSize(width: 435, height: 151)), display: false)
      panel.windowDidEndLiveResize(Notification(name: NSWindow.didEndLiveResizeNotification, object: panel))

      XCTAssertEqual(Defaults[.windowSize].height, 423)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 2)
  }

  func testProgrammaticResizeKeepsTopEdgeStable() {
    let expectation = expectation(description: "stable resize anchor")

    Task { @MainActor in
      Defaults[.windowSize] = NSSize(width: 435, height: 423)
      let panel = FloatingPanel(
        contentRect: NSRect(origin: .zero, size: Defaults[.windowSize]),
        identifier: "floating-panel-stable-resize-test",
        onClose: {}
      ) {
        EmptyView()
      }
      panel.setFrame(NSRect(origin: NSPoint(x: 100, y: 200), size: Defaults[.windowSize]), display: false)
      let originalMaxY = panel.frame.maxY
      let originalContentWidth = panel.contentRect(forFrameRect: panel.frame).width

      panel.verticallyResize(to: 151)

      XCTAssertEqual(panel.contentRect(forFrameRect: panel.frame).size, NSSize(width: originalContentWidth, height: 151))
      XCTAssertEqual(panel.frame.maxY, originalMaxY)

      panel.verticallyResize(to: 300)

      XCTAssertEqual(panel.contentRect(forFrameRect: panel.frame).size, NSSize(width: originalContentWidth, height: 300))
      XCTAssertEqual(panel.frame.maxY, originalMaxY)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 2)
  }

  func testFloatingPanelSuppressesStandardTrafficLights() {
    let expectation = expectation(description: "suppressed traffic lights")

    Task { @MainActor in
      let panel = FloatingPanel(
        contentRect: NSRect(origin: .zero, size: NSSize(width: 435, height: 423)),
        identifier: "floating-panel-traffic-lights-test",
        onClose: {}
      ) {
        EmptyView()
      }

      XCTAssertNil(panel.accessibilityCloseButton)
      XCTAssertNil(panel.accessibilityZoomButton)
      XCTAssertNil(panel.accessibilityMinimizeButton)
      XCTAssertNil(panel.accessibilityFullScreenButton)
      XCTAssertFalse(panel.standardWindowButton(.closeButton)?.isEnabled ?? true)
      XCTAssertFalse(panel.standardWindowButton(.miniaturizeButton)?.isEnabled ?? true)
      XCTAssertFalse(panel.standardWindowButton(.zoomButton)?.isEnabled ?? true)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 2)
  }
}

class HistoryPinnedReorderTests: XCTestCase {
  let savedSize = Defaults[.size]
  let savedSortBy = Defaults[.sortBy]
  let savedPinTo = Defaults[.pinTo]
  let history = History.shared

  override func setUpWithError() throws {
    try super.setUpWithError()
    runOnMainActor(description: "Reset history") { [self] in
      self.history.clearAll()
      Defaults[.size] = 10
      Defaults[.sortBy] = .firstCopiedAt
      Defaults[.pinTo] = .top
    }
  }

  override func tearDownWithError() throws {
    runOnMainActor(description: "Restore history") { [self] in
      self.history.clearAll()
      Defaults[.size] = self.savedSize
      Defaults[.sortBy] = self.savedSortBy
      Defaults[.pinTo] = self.savedPinTo
    }
    try super.tearDownWithError()
  }

  func testPinnedReorderMovesItemToFirstSlot() async {
    await MainActor.run {
      let firstPinned = history.add(historyItem("first pinned"))
      let secondPinned = history.add(historyItem("second pinned"))
      history.add(historyItem("regular"))

      history.togglePin(firstPinned)
      history.togglePin(secondPinned)
      history.movePinned(itemWithID: secondPinned.id, toPinnedIndex: 0)

      XCTAssertEqual(history.items.compactMap { $0.item.text }, ["second pinned", "first pinned", "regular"])
      XCTAssertEqual(firstPinned.item.pinOrder, 1)
      XCTAssertEqual(secondPinned.item.pinOrder, 0)
    }
  }

  func testPinnedReorderMovesFirstItemToLastSlot() async {
    await MainActor.run {
      let firstPinned = history.add(historyItem("first pinned"))
      let secondPinned = history.add(historyItem("second pinned"))
      let thirdPinned = history.add(historyItem("third pinned"))
      history.add(historyItem("regular"))

      history.togglePin(firstPinned)
      history.togglePin(secondPinned)
      history.togglePin(thirdPinned)
      history.movePinned(itemWithID: firstPinned.id, toPinnedIndex: 3)

      XCTAssertEqual(
        history.items.compactMap { $0.item.text },
        ["second pinned", "third pinned", "first pinned", "regular"]
      )
      XCTAssertEqual(secondPinned.item.pinOrder, 0)
      XCTAssertEqual(thirdPinned.item.pinOrder, 1)
      XCTAssertEqual(firstPinned.item.pinOrder, 2)
    }
  }

  func testPinnedReorderIgnoresUnchangedSlots() async {
    await MainActor.run {
      let firstPinned = history.add(historyItem("first pinned"))
      let secondPinned = history.add(historyItem("second pinned"))
      let thirdPinned = history.add(historyItem("third pinned"))

      history.togglePin(firstPinned)
      history.togglePin(secondPinned)
      history.togglePin(thirdPinned)

      history.movePinned(itemWithID: secondPinned.id, toPinnedIndex: 1)
      history.movePinned(itemWithID: secondPinned.id, toPinnedIndex: 2)

      XCTAssertEqual(
        history.items.compactMap { $0.item.text },
        ["first pinned", "second pinned", "third pinned"]
      )
      XCTAssertEqual(firstPinned.item.pinOrder, 0)
      XCTAssertEqual(secondPinned.item.pinOrder, 1)
      XCTAssertEqual(thirdPinned.item.pinOrder, 2)
    }
  }

  func testPinnedReorderPersistsAfterReload() async throws {
    await MainActor.run {
      let firstPinned = history.add(historyItem("first pinned"))
      let secondPinned = history.add(historyItem("second pinned"))
      let thirdPinned = history.add(historyItem("third pinned"))

      history.togglePin(firstPinned)
      history.togglePin(secondPinned)
      history.togglePin(thirdPinned)
      history.movePinned(itemWithID: thirdPinned.id, toPinnedIndex: 0)
    }

    try await history.load()

    await MainActor.run {
      XCTAssertEqual(
        history.items.compactMap { $0.item.text },
        ["third pinned", "first pinned", "second pinned"]
      )
      XCTAssertEqual(history.items.compactMap(\.item.pinOrder), [0, 1, 2])
    }
  }

  private func runOnMainActor(description: String, _ work: @escaping @MainActor () -> Void) {
    let expectation = expectation(description: description)

    Task { @MainActor in
      work()
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 2)
  }

  @MainActor
  private func historyItem(_ value: String) -> HistoryItem {
    let contents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: value.data(using: .utf8)
      )
    ]
    let item = HistoryItem()
    Storage.shared.context.insert(item)
    item.contents = contents
    item.numberOfCopies = 1
    item.title = item.generateTitle()

    return item
  }
}
