import XCTest
import Defaults
import SwiftData
@testable import FlowClip

@MainActor
class HistoryItemDecoratorTests: XCTestCase {
  let boldFont = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
  let savedHighlightMatch = Defaults[.highlightMatch]
  let savedImageMaxHeight = Defaults[.imageMaxHeight]

  var firstCopiedAt: Date! {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
    return formatter.date(from: "2020/07/10 12:31:34")
  }

  var lastCopiedAt: Date! {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
    return formatter.date(from: "2020/07/10 12:41:34")
  }

  override func setUp() {
    super.setUp()
    Defaults[.highlightMatch] = .bold
    Defaults[.imageMaxHeight] = 40
  }

  override func tearDown() {
    super.tearDown()
    Defaults[.imageMaxHeight] = savedImageMaxHeight
    Defaults[.highlightMatch] = savedHighlightMatch
  }

  func testString() {
    let title = "foo"
    let itemDecorator = historyItemDecorator(title)
    XCTAssertEqual(itemDecorator.title, title)
    XCTAssertNil(itemDecorator.previewImage)
    XCTAssertNil(itemDecorator.thumbnailImage)
  }

  func testRTF() {
    let rtf = NSAttributedString(string: "foo").rtf(
      from: NSRange(0...2),
      documentAttributes: [:]
    )
    let itemDecorator = historyItemDecorator(rtf, .rtf)
    XCTAssertEqual(itemDecorator.title, "foo")
    XCTAssertNil(itemDecorator.previewImage)
    XCTAssertNil(itemDecorator.thumbnailImage)
  }

  func testHTML() {
    let html = "<a href='#'>foo</a>".data(using: .utf8)
    let itemDecorator = historyItemDecorator(html, .html)
    XCTAssertEqual(itemDecorator.title, "foo")
    XCTAssertNil(itemDecorator.previewImage)
    XCTAssertNil(itemDecorator.thumbnailImage)
  }

  func testImage() {
    let image = NSImage(named: "StatusBarMenuImage")!
    let itemDecorator = historyItemDecorator(image)
    itemDecorator.sizeImages()
    XCTAssertEqual(itemDecorator.title, "")
    XCTAssertEqual(itemDecorator.previewImage!.size, image.size)
    XCTAssertEqual(itemDecorator.thumbnailImage!.size, image.size)
  }

  // We also need to add test for image with width bigger than max width.
  func testImageWithHeightBiggerThanMaxHeight() {
    let image = NSImage(named: "NSApplicationIcon")!
    let itemDecorator = historyItemDecorator(image)
    itemDecorator.sizeImages()
    XCTAssertEqual(itemDecorator.thumbnailImage!.size, NSSize(width: 40, height: 40))
  }

  func testCleanupPreviewImageKeepsThumbnail() {
    let image = NSImage(named: "NSApplicationIcon")!
    let itemDecorator = historyItemDecorator(image)
    itemDecorator.sizeImages()

    XCTAssertNotNil(itemDecorator.thumbnailImage)
    XCTAssertNotNil(itemDecorator.previewImage)

    itemDecorator.cleanupPreviewImage()

    XCTAssertNotNil(itemDecorator.thumbnailImage)
    XCTAssertNil(itemDecorator.previewImage)
  }

  func testSelectingImageDoesNotEagerlyGeneratePreviewImage() async {
    let image = NSImage(named: "NSApplicationIcon")!
    let itemDecorator = historyItemDecorator(image)

    itemDecorator.isSelected = true
    await Task.yield()

    XCTAssertNil(itemDecorator.previewImage)
    XCTAssertNil(itemDecorator.previewImageGenerationTask)
  }

  func testFile() {
    let url = URL(fileURLWithPath: "/tmp/foo.bar")
    let itemDecorator = historyItemDecorator(url)
    XCTAssertEqual(itemDecorator.title, "file:///tmp/foo.bar")
    XCTAssertNil(itemDecorator.previewImage)
    XCTAssertNil(itemDecorator.thumbnailImage)
  }

  func testFileWithEscapedChars() {
    let url = URL(fileURLWithPath: "/tmp/产品培训/产品培训.txt")
    let itemDecorator = historyItemDecorator(url)
    XCTAssertEqual(itemDecorator.title, "file:///tmp/产品培训/产品培训.txt")
    XCTAssertNil(itemDecorator.previewImage)
    XCTAssertNil(itemDecorator.thumbnailImage)
  }

  func testItemWithoutData() {
    let itemDecorator = historyItemDecorator(nil)
    XCTAssertEqual(itemDecorator.title, "")
    XCTAssertNil(itemDecorator.previewImage)
    XCTAssertNil(itemDecorator.thumbnailImage)
  }

  func testUnpinnedByDefault() {
    let itemDecorator = historyItemDecorator("foo")
    XCTAssertNil(itemDecorator.item.pin)
    XCTAssertFalse(itemDecorator.isPinned)
  }

  func testPin() {
    let itemDecorator = historyItemDecorator("foo")
    itemDecorator.togglePin()
    XCTAssertNotNil(itemDecorator.item.pin)
    XCTAssertNotNil(itemDecorator.item.pinOrder)
    XCTAssertTrue(itemDecorator.isPinned)
  }

  func testUnpin() {
    let itemDecorator = historyItemDecorator("foo")
    itemDecorator.togglePin()
    itemDecorator.togglePin()
    XCTAssertNil(itemDecorator.item.pin)
    XCTAssertNil(itemDecorator.item.pinOrder)
    XCTAssertFalse(itemDecorator.isPinned)
  }

  func testHighlight() {
    let itemDecorator = historyItemDecorator("foo bar baz")
    itemDecorator.highlight("random", [
      range(from: 1, to: 2, in: itemDecorator),
      range(from: 8, to: 10, in: itemDecorator)
    ])
    var expectedTitle = AttributedString("foo bar baz")
    expectedTitle[expectedTitle.range(of: "oo")!].font = .bold(.body)()
    expectedTitle[expectedTitle.range(of: "baz")!].font = .bold(.body)()
    XCTAssertEqual(itemDecorator.attributedTitle, expectedTitle)
    itemDecorator.highlight("", [])
    XCTAssertEqual(itemDecorator.attributedTitle, nil)
  }

  private func historyItemDecorator(
    _ value: String?,
    application: String? = "com.apple.finder"
  ) -> HistoryItemDecorator {
    let contents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: value?.data(using: .utf8)
      )
    ]
    let item = HistoryItem()
    Storage.shared.context.insert(item)
    item.contents = contents
    item.title = item.generateTitle()
    item.application = application
    item.firstCopiedAt = firstCopiedAt
    item.lastCopiedAt = lastCopiedAt

    return HistoryItemDecorator(item)
  }

  private func historyItemDecorator(
    _ value: Data?,
    _ type: NSPasteboard.PasteboardType
  ) -> HistoryItemDecorator {
    let contents = [
      HistoryItemContent(
        type: type.rawValue,
        value: value
      )
    ]
    let item = HistoryItem()
    Storage.shared.context.insert(item)
    item.contents = contents
    item.title = item.generateTitle()
    item.application = "com.apple.finder"
    item.firstCopiedAt = firstCopiedAt
    item.lastCopiedAt = lastCopiedAt
    item.numberOfCopies = 2

    return HistoryItemDecorator(item)
  }

  private func historyItemDecorator(_ value: NSImage) -> HistoryItemDecorator {
    let contents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.tiff.rawValue,
        value: value.tiffRepresentation!
      )
    ]
    let item = HistoryItem()
    Storage.shared.context.insert(item)
    item.contents = contents
    item.title = item.generateTitle()
    item.application = "com.apple.finder"
    item.firstCopiedAt = firstCopiedAt
    item.lastCopiedAt = lastCopiedAt
    item.numberOfCopies = 2

    return HistoryItemDecorator(item)
  }

  private func historyItemDecorator(_ value: URL) -> HistoryItemDecorator {
    let contents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.fileURL.rawValue,
        value: value.dataRepresentation
      ),
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: value.lastPathComponent.data(using: .utf8)
      )
    ]
    let item = HistoryItem()
    Storage.shared.context.insert(item)
    item.contents = contents
    item.title = item.generateTitle()
    item.application = "com.apple.finder"
    item.firstCopiedAt = firstCopiedAt
    item.lastCopiedAt = lastCopiedAt
    item.numberOfCopies = 2

    return HistoryItemDecorator(item)
  }

  // swiftlint:disable:next identifier_name
  private func range(from: Int, to: Int, in item: HistoryItemDecorator) -> Range<String.Index> {
    let startIndex = item.title.startIndex
    let lowerBound = item.title.index(startIndex, offsetBy: from)
    let upperBound = item.title.index(startIndex, offsetBy: to + 1)

    return lowerBound..<upperBound
  }
}

@MainActor
class HistoryStorageCleanupTests: XCTestCase {
  let history = History.shared

  override func setUp() {
    super.setUp()
    history.clearAll()
  }

  override func tearDown() {
    history.clearAll()
    super.tearDown()
  }

  func testAddingSameDoesNotLeaveExtraContentsInStorage() {
    history.add(historyItem("foo"))
    history.add(historyItem("foo"))

    XCTAssertEqual(history.items.count, 1)
    XCTAssertEqual(contentCount(), 1)
  }

  func testRemovingDeletesContentsFromStorage() {
    let foo = history.add(historyItem("foo"))
    let bar = history.add(historyItem("bar"))

    history.delete(foo)

    XCTAssertEqual(history.items, [bar])
    XCTAssertEqual(contentCount(), 1)
  }

  func testClearDeletesUnpinnedContentsAndKeepsPinnedContents() {
    let pinned = history.add(historyItem("pinned"))
    pinned.item.pin = "b"
    pinned.item.pinOrder = 0
    try? Storage.shared.context.save()
    history.add(historyItem("regular"))

    history.clear()

    XCTAssertEqual(history.items, [pinned])
    XCTAssertEqual(contentCount(), 1)
  }

  func testClearAllDeletesAllContents() {
    history.add(historyItem("foo"))
    history.add(historyItem("bar"))

    history.clearAll()

    XCTAssertTrue(history.items.isEmpty)
    XCTAssertEqual(contentCount(), 0)
  }

  func testLoadRemovesOrphanedContents() async throws {
    let orphanedContent = HistoryItemContent(
      type: NSPasteboard.PasteboardType.string.rawValue,
      value: "orphan".data(using: .utf8)
    )
    Storage.shared.context.insert(orphanedContent)
    try? Storage.shared.context.save()

    XCTAssertEqual(contentCount(), 1)

    try await history.load()

    XCTAssertEqual(contentCount(), 0)
  }

  func testLoadExternalizesExistingLargeInlineContents() async throws {
    let data = Data(repeating: 1, count: HistoryItemContent.externalStorageThreshold + 1)
    let content = HistoryItemContent(type: NSPasteboard.PasteboardType.tiff.rawValue)
    content.value = data
    content.valueFileName = nil
    let item = HistoryItem(contents: [content])
    Storage.shared.context.insert(item)
    try? Storage.shared.context.save()

    XCTAssertNotNil(content.value)
    XCTAssertNil(content.valueFileName)

    try await history.load()

    XCTAssertNil(content.value)
    XCTAssertNotNil(content.valueFileName)
    XCTAssertTrue(content.hasStoredValueFile)
    XCTAssertEqual(content.resolvedValue, data)
  }

  func testLargeContentIsStoredOutsideModelValue() {
    let data = Data(repeating: 1, count: HistoryItemContent.externalStorageThreshold + 1)
    let content = HistoryItemContent(type: NSPasteboard.PasteboardType.tiff.rawValue, value: data)
    defer { content.deleteStoredValueFile() }

    XCTAssertNil(content.value)
    XCTAssertNotNil(content.valueFileName)
    XCTAssertTrue(content.hasStoredValueFile)
    XCTAssertEqual(content.resolvedValue, data)
  }

  func testHasImageDataDoesNotLoadExternalValue() {
    let data = Data(repeating: 1, count: HistoryItemContent.externalStorageThreshold + 1)
    let content = HistoryItemContent(type: NSPasteboard.PasteboardType.tiff.rawValue, value: data)
    defer { content.deleteStoredValueFile() }
    let item = HistoryItem(contents: [content])

    XCTAssertTrue(item.hasImageData)
    XCTAssertNil(content.value)
  }

  func testClearAllDeletesExternalContentFiles() {
    let data = Data(repeating: 65, count: HistoryItemContent.externalStorageThreshold + 1)
    let content = HistoryItemContent(type: NSPasteboard.PasteboardType.string.rawValue, value: data)
    let item = HistoryItem(contents: [content])
    Storage.shared.context.insert(item)
    item.title = item.generateTitle()
    history.add(item)

    XCTAssertTrue(content.hasStoredValueFile)

    history.clearAll()

    XCTAssertFalse(content.hasStoredValueFile)
    XCTAssertEqual(contentCount(), 0)
  }

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

  private func contentCount() -> Int {
    (try? Storage.shared.context.fetchCount(FetchDescriptor<HistoryItemContent>())) ?? -1
  }
}
