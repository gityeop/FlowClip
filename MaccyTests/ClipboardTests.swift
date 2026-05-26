import XCTest
import Defaults
@testable import FlowClip

// swiftlint:disable type_body_length
class ClipboardTests: XCTestCase {
  let clipboard = Clipboard.shared
  let pasteboard = NSPasteboard.general
  let image = NSImage(named: "NSInfo")!
  let coloredString = NSAttributedString(string: "foo",
                                         attributes: [.foregroundColor: NSColor.red])

  let dynamicType = NSPasteboard.PasteboardType(rawValue: "dyn.ah62d4qmxhk4d425try1g44pdsm11g55gsu1e82xnqzv")
  let customType = NSPasteboard.PasteboardType(rawValue: "org.maccy.ConfidentialType")
  let fileURLType = NSPasteboard.PasteboardType.fileURL
  let htmlType = NSPasteboard.PasteboardType.html
  let rtfType = NSPasteboard.PasteboardType.rtf
  let stringType = NSPasteboard.PasteboardType.string
  let tiffType = NSPasteboard.PasteboardType.tiff
  let transientType = NSPasteboard.PasteboardType.transient
  let unknownType = NSPasteboard.PasteboardType(rawValue: "com.apple.AnnotationKit.AnnotationItem")

  let savedEnabledTypes = Defaults[.enabledPasteboardTypes]
  let savedIgnoreEvents = Defaults[.ignoreEvents]
  let savedIgnoreAllAppsExceptListed = Defaults[.ignoreAllAppsExceptListed]
  let savedIgnoredApps = Defaults[.ignoredApps]
  let savedIgnoredPasteboardTypes = Defaults[.ignoredPasteboardTypes]
  let savedRemoveFormattingByDefault = Defaults[.removeFormattingByDefault]
  let savedQueueAutoSplitText = Defaults[.queueAutoSplitText]
  let savedQueueSeparator = Defaults[.queueSeparator]
  let savedCustomQueueSeparator = Defaults[.customQueueSeparator]
  let savedQueueSeparatorPresets = Defaults[.queueSeparatorPresets]
  let savedQueueSeparatorPresetModes = Defaults[.queueSeparatorPresetModes]
  let savedQueueActiveSeparatorPresetIndex = Defaults[.queueActiveSeparatorPresetIndex]

  override func setUp() {
    super.setUp()
    Defaults[.ignoreAllAppsExceptListed] = false
    Defaults[.ignoreEvents] = false
    QueueClipboard.shared.clear()
  }

  override func tearDown() {
    super.tearDown()
    Defaults[.enabledPasteboardTypes] = savedEnabledTypes
    Defaults[.ignoreEvents] = savedIgnoreEvents
    Defaults[.ignoreOnlyNextEvent] = false
    Defaults[.ignoreAllAppsExceptListed] = savedIgnoreAllAppsExceptListed
    Defaults[.ignoredApps] = savedIgnoredApps
    Defaults[.ignoredPasteboardTypes] = savedIgnoredPasteboardTypes
    Defaults[.removeFormattingByDefault] = savedRemoveFormattingByDefault
    Defaults[.queueAutoSplitText] = savedQueueAutoSplitText
    Defaults[.queueSeparator] = savedQueueSeparator
    Defaults[.customQueueSeparator] = savedCustomQueueSeparator
    Defaults[.queueSeparatorPresets] = savedQueueSeparatorPresets
    Defaults[.queueSeparatorPresetModes] = savedQueueSeparatorPresetModes
    Defaults[.queueActiveSeparatorPresetIndex] = savedQueueActiveSeparatorPresetIndex
    QueueClipboard.shared.clear()
    clipboard.clearHooks()
  }

  private func makeQueueHistoryItem(_ text: String) -> HistoryItem {
    let item = HistoryItem(contents: [
      HistoryItemContent(type: stringType.rawValue, value: text.data(using: .utf8)!)
    ])
    item.title = item.generateTitle()
    return item
  }

  private func makeLargeImageContent() -> HistoryItemContent {
    HistoryItemContent(
      type: tiffType.rawValue,
      value: Data(repeating: 1, count: HistoryItemContent.externalStorageThreshold + 1)
    )
  }

  func testChangesListenerAndAddHooks() {
    let hookExpectation = expectation(description: "Hook is called")
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString("bar", forType: .string)
    waitForExpectations(timeout: 2)
  }

  func testIgnoreStringWithOnlySpaces() {
    let hookExpectation = expectation(description: "Hook is called")
    hookExpectation.isInverted = true
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString(" ", forType: .string)
    waitForExpectations(timeout: 2)
  }

  func testIgnoreStringWithOnlyNewlines() {
    let hookExpectation = expectation(description: "Hook is called")
    hookExpectation.isInverted = true
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString("\n", forType: .string)
    waitForExpectations(timeout: 2)
  }

  func testDoesNotIgnoreRTF() {
    let hookExpectation = expectation(description: "Hook is called")
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    let rtf = NSAttributedString(string: "foo").rtf(
      from: NSRange(0...2),
      documentAttributes: [:]
    )
    pasteboard.declareTypes([.rtf], owner: nil)
    pasteboard.setData(rtf, forType: .rtf)
    waitForExpectations(timeout: 2)
  }

  func testDoesNotIgnoreHTML() {
    let hookExpectation = expectation(description: "Hook is called")
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([.html], owner: nil)
    pasteboard.setString("foo", forType: .html)
    waitForExpectations(timeout: 2)
  }

  func testIgnoreEventsIsEnabled() {
    Defaults[.ignoreEvents] = true

    let hookExpectation = expectation(description: "Hook is called")
    hookExpectation.isInverted = true
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString("foo", forType: .string)
    waitForExpectations(timeout: 2)
  }

  func testIgnoreOnlyNextEventIsEnabled() {
    Defaults[.ignoreEvents] = true
    Defaults[.ignoreOnlyNextEvent] = true

    let hookExpectation = expectation(description: "Hook is called")
    hookExpectation.isInverted = true
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString("foo", forType: .string)
    waitForExpectations(timeout: 2)

    XCTAssertFalse(Defaults[.ignoreEvents])
    XCTAssertFalse(Defaults[.ignoreOnlyNextEvent])
  }

  func testIgnoreApplication() {
    Defaults[.ignoredApps] = ["com.apple.dt.Xcode", "com.apple.finder"] // Finder is on Bitrise

    let hookExpectation = expectation(description: "Hook is called")
    hookExpectation.isInverted = true
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString("bar", forType: .string)
    waitForExpectations(timeout: 2)
  }

  func testIgnoreAllApplicationsExcept() {
    Defaults[.ignoreAllAppsExceptListed] = true
    Defaults[.ignoredApps] = ["com.apple.dt.Xcode", "com.apple.finder"] // Finder is on Bitrise

    let hookExpectation = expectation(description: "Hook is called")
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString("bar", forType: .string)
    waitForExpectations(timeout: 2)
  }

  func testIgnoreTransientTypes() {
    let hookExpectation = expectation(description: "Hook is called")
    hookExpectation.isInverted = true
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([.string, transientType], owner: nil)
    pasteboard.setString("bar", forType: .string)
    waitForExpectations(timeout: 2)
  }

  func testIgnoreCustomTypes() {
    Defaults[.ignoredPasteboardTypes] = [customType.rawValue]

    let hookExpectation = expectation(description: "Hook is called")
    hookExpectation.isInverted = true
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([.string, customType], owner: nil)
    pasteboard.setString("bar", forType: .string)
    waitForExpectations(timeout: 2)
  }

  func testIgnoreCopiesWithUnknownTypes() {
    let hookExpectation = expectation(description: "Hook is called")
    hookExpectation.isInverted = true
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([unknownType], owner: nil)
    pasteboard.setString(" ", forType: unknownType)
    waitForExpectations(timeout: 2)
  }

  @MainActor
  func testCopy() {
    let imageData = image.tiffRepresentation!
    let contents = [
      HistoryItemContent(type: stringType.rawValue, value: "foo".data(using: .utf8)!),
      HistoryItemContent(type: tiffType.rawValue, value: imageData),
      HistoryItemContent(type: fileURLType.rawValue, value: "file://foo.bar".data(using: .utf8)!)
    ]
    let item = HistoryItem()
    Storage.shared.context.insert(item)
    item.contents = contents
    item.application = "com.foo.bar"
    clipboard.copy(item)
    XCTAssertEqual(pasteboard.string(forType: .string), "foo")
    XCTAssertEqual(pasteboard.data(forType: .tiff), imageData)
    XCTAssertEqual(pasteboard.string(forType: .fileURL), "file://foo.bar")
    XCTAssertEqual(pasteboard.string(forType: .fromMaccy), "")
    XCTAssertEqual(pasteboard.string(forType: .source), "com.foo.bar")
  }

  @MainActor
  func testCopyWithoutFormatting() {
    let contents = [
      HistoryItemContent(type: stringType.rawValue, value: "foo".data(using: .utf8)!),
      HistoryItemContent(type: fileURLType.rawValue, value: "file://foo.bar".data(using: .utf8)!),
      HistoryItemContent(type: rtfType.rawValue,
                         value: coloredString.rtf(from: NSRange(location: 0, length: coloredString.length),
                                                  documentAttributes: [:]))
    ]
    let item = HistoryItem()
    Storage.shared.context.insert(item)
    item.contents = contents
    item.application = "com.foo.bar"
    clipboard.copy(item, removeFormatting: true)
    XCTAssertEqual(pasteboard.string(forType: .string), "foo")
    XCTAssertEqual(pasteboard.string(forType: .fromMaccy), "")
    XCTAssertEqual(pasteboard.string(forType: .source), "com.foo.bar")
    XCTAssertEqual(pasteboard.string(forType: .fileURL), "file://foo.bar")
    XCTAssertNil(pasteboard.data(forType: .rtf))
  }

  func testQueueTextSplitterSplitsBulletListBySingleNewline() {
    let result = QueueTextSplitter.split(text: "- one\n- two\n- three")
    XCTAssertEqual(result, ["- one", "- two", "- three"])
  }

  func testQueueTextSplitterSplitsParagraphsByBlankLine() {
    let result = QueueTextSplitter.split(text: "First paragraph.\nStill first.\n\nSecond paragraph.")
    XCTAssertEqual(result, ["First paragraph.", "Still first.", "Second paragraph."])
  }

  func testQueueTextSplitterSplitsLikelyWrappedParagraphOnSingleNewline() {
    let result = QueueTextSplitter.split(text: "This is a wrapped paragraph\nand it should stay as one item.")
    XCTAssertEqual(result, ["This is a wrapped paragraph", "and it should stay as one item."])
  }

  func testQueueClipboardAutoSplitAddsMultipleItems() {
    Defaults[.queueAutoSplitText] = true

    let item = HistoryItem(contents: [
      HistoryItemContent(type: stringType.rawValue, value: "- one\n- two\n- three".data(using: .utf8)!)
    ])
    item.title = item.generateTitle()

    QueueClipboard.shared.addFromClipboard(item)

    XCTAssertEqual(QueueClipboard.shared.items.count, 3)
    XCTAssertEqual(QueueClipboard.shared.items.compactMap { $0.item.text }, ["- one", "- two", "- three"])
  }

  func testQueueSeparatorCurrentPresetPreviewKeepsLiteralSpaces() {
    Defaults[.queueSeparatorPresets] = [", "] + Array(repeating: "", count: QueueSeparator.presetCount - 1)
    Defaults[.queueSeparatorPresetModes] = [QueueSeparator.custom.rawValue]
      + Array(repeating: QueueSeparator.custom.rawValue, count: QueueSeparator.presetCount - 1)
    Defaults[.queueActiveSeparatorPresetIndex] = 0

    XCTAssertEqual(QueueSeparator.currentPresetPreview(), "A, B")
  }

  func testQueueSeparatorCurrentPresetPreviewShowsEmptyPreset() {
    Defaults[.queueSeparatorPresets] = Array(repeating: "", count: QueueSeparator.presetCount)
    Defaults[.queueSeparatorPresetModes] = QueueSeparator.defaultPresetModes
    Defaults[.queueActiveSeparatorPresetIndex] = 0

    XCTAssertEqual(QueueSeparator.currentPresetPreview(), "A∅B")
  }

  func testQueueSeparatorCurrentPresetPreviewUsesBuiltinMode() {
    Defaults[.queueSeparatorPresets] = [" / "] + Array(repeating: "", count: QueueSeparator.presetCount - 1)
    Defaults[.queueSeparatorPresetModes] = [QueueSeparator.space.rawValue]
      + Array(repeating: QueueSeparator.custom.rawValue, count: QueueSeparator.presetCount - 1)
    Defaults[.queueActiveSeparatorPresetIndex] = 0

    XCTAssertEqual(QueueSeparator.currentPresetPreview(), "A B")
  }

  func testQueueSeparatorSamplePreviewKeepsVisibleNewlineGlyph() {
    XCTAssertEqual(QueueSeparator.samplePreview(for: "\\n"), "A⏎B")
  }

  func testQueueSeparatorSamplePreviewTruncatesLongSeparator() {
    XCTAssertEqual(QueueSeparator.samplePreview(for: "-----"), "A---…B")
  }

  func testQueueSeparatorSelectPresetSyncsSeparatorModeAndCustomValue() {
    Defaults[.queueSeparatorPresets] = [" / ", "\\n"] + Array(repeating: "", count: QueueSeparator.presetCount - 2)
    Defaults[.queueSeparatorPresetModes] = [QueueSeparator.space.rawValue, QueueSeparator.custom.rawValue]
      + Array(repeating: QueueSeparator.custom.rawValue, count: QueueSeparator.presetCount - 2)

    QueueSeparator.selectPreset(1)

    XCTAssertEqual(Defaults[.queueActiveSeparatorPresetIndex], 1)
    XCTAssertEqual(Defaults[.queueSeparator], .custom)
    XCTAssertEqual(Defaults[.customQueueSeparator], "\\n")
    XCTAssertEqual(Defaults[.queueSeparator].value, "\n")
  }

  func testQueueSeparatorCycleCurrentPresetSkipsEmptyCustomPresets() {
    Defaults[.queueSeparatorPresets] = ["", "", "\\n"] + Array(repeating: "", count: QueueSeparator.presetCount - 3)
    Defaults[.queueSeparatorPresetModes] = [QueueSeparator.custom.rawValue, QueueSeparator.space.rawValue, QueueSeparator.custom.rawValue]
      + Array(repeating: QueueSeparator.custom.rawValue, count: QueueSeparator.presetCount - 3)
    Defaults[.queueActiveSeparatorPresetIndex] = 1
    Defaults[.queueSeparator] = .space

    let nextIndex = QueueSeparator.cycleCurrentPreset()

    XCTAssertEqual(nextIndex, 2)
    XCTAssertEqual(Defaults[.queueSeparator], .custom)
    XCTAssertEqual(Defaults[.customQueueSeparator], "\\n")
  }

  func testQueueSeparatorCycleCurrentPresetKeepsBuiltInAndCustomModesAligned() {
    Defaults[.queueSeparatorPresets] = ["P1", "P2", "P3", "P4", ""] + Array(repeating: "", count: QueueSeparator.presetCount - 5)
    Defaults[.queueSeparatorPresetModes] = [
      QueueSeparator.custom.rawValue,
      QueueSeparator.custom.rawValue,
      QueueSeparator.custom.rawValue,
      QueueSeparator.custom.rawValue,
      QueueSeparator.none.rawValue
    ] + Array(repeating: QueueSeparator.custom.rawValue, count: QueueSeparator.presetCount - 5)
    Defaults[.queueActiveSeparatorPresetIndex] = 3
    Defaults[.queueSeparator] = .custom
    Defaults[.customQueueSeparator] = "P4"

    XCTAssertEqual(QueueSeparator.cycleCurrentPreset(), 4)
    XCTAssertEqual(Defaults[.queueSeparator], .none)
    XCTAssertNil(QueueSeparator.currentPresetValue())

    XCTAssertEqual(QueueSeparator.cycleCurrentPreset(), 0)
    XCTAssertEqual(Defaults[.queueSeparator], .custom)
    XCTAssertEqual(Defaults[.customQueueSeparator], "P1")
    XCTAssertEqual(QueueSeparator.currentPresetValue(), "P1")
  }

  func testQueueSeparatorMigrateLegacyPresetModesPreservesExistingPresetStrings() {
    let presets = [" / ", "\\n"] + Array(repeating: "", count: QueueSeparator.presetCount - 2)

    let migratedModes = QueueSeparator.migrateLegacyPresetModes(
      QueueSeparator.defaultPresetModes,
      presetValues: presets,
      activePresetIndex: 1,
      currentSeparator: .space
    )

    XCTAssertEqual(migratedModes[0], QueueSeparator.custom.rawValue)
    XCTAssertEqual(migratedModes[1], QueueSeparator.space.rawValue)
  }

  func testQueueClipboardMoveBeforeItemReordersItems() {
    QueueClipboard.shared.add(makeQueueHistoryItem("one"))
    QueueClipboard.shared.add(makeQueueHistoryItem("two"))
    QueueClipboard.shared.add(makeQueueHistoryItem("three"))

    let queueItemIDs = QueueClipboard.shared.items.map(\.id)
    QueueClipboard.shared.move(itemWithID: queueItemIDs[2], beforeItemWithID: queueItemIDs[0])

    XCTAssertEqual(QueueClipboard.shared.items.compactMap { $0.item.text }, ["three", "one", "two"])
  }

  func testQueueClipboardMoveToEndMovesItemToLastPosition() {
    QueueClipboard.shared.add(makeQueueHistoryItem("one"))
    QueueClipboard.shared.add(makeQueueHistoryItem("two"))
    QueueClipboard.shared.add(makeQueueHistoryItem("three"))

    let firstID = QueueClipboard.shared.items[0].id
    QueueClipboard.shared.moveToEnd(itemWithID: firstID)

    XCTAssertEqual(QueueClipboard.shared.items.compactMap { $0.item.text }, ["two", "three", "one"])
  }

  func testQueueClipboardClearDeletesExternalContentFiles() {
    let content = makeLargeImageContent()
    let item = HistoryItem(contents: [content])
    QueueClipboard.shared.add(item)

    XCTAssertTrue(content.hasStoredValueFile)

    QueueClipboard.shared.clear()

    XCTAssertFalse(content.hasStoredValueFile)
  }

  func testQueueClipboardRemoveDeletesExternalContentFiles() {
    let content = makeLargeImageContent()
    let item = HistoryItem(contents: [content])
    QueueClipboard.shared.add(item)

    let queueItemID = QueueClipboard.shared.items[0].id
    XCTAssertTrue(content.hasStoredValueFile)

    QueueClipboard.shared.remove(id: queueItemID)

    XCTAssertFalse(content.hasStoredValueFile)
  }

  @MainActor
  func testQueuePasteCopyRespectsRemoveFormattingPreference() {
    let item = HistoryItem(contents: [
      HistoryItemContent(type: stringType.rawValue, value: "foo".data(using: .utf8)!),
      HistoryItemContent(type: rtfType.rawValue,
                         value: coloredString.rtf(
                           from: NSRange(location: 0, length: coloredString.length),
                           documentAttributes: [:]
                         ))
    ])

    Defaults[.removeFormattingByDefault] = true
    clipboard.copy(item, removeFormatting: Defaults[.removeFormattingByDefault])
    XCTAssertEqual(pasteboard.string(forType: .string), "foo")
    XCTAssertNil(pasteboard.data(forType: .rtf))

    Defaults[.removeFormattingByDefault] = false
    clipboard.copy(item, removeFormatting: Defaults[.removeFormattingByDefault])
    XCTAssertEqual(pasteboard.string(forType: .string), "foo")
    XCTAssertNotNil(pasteboard.data(forType: .rtf))
  }

  func testHandlesItemsWithoutData() {
    let hookExpectation = expectation(description: "Hook is called")
    pasteboard.clearContents()
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([.fileURL, .string], owner: nil)
    // fileURL is left without data
    pasteboard.setString("bar", forType: .string)
    waitForExpectations(timeout: 2)
  }

  func testMergesMultipleItems() {
    let hookExpectation = expectation(description: "Hook is called")
    clipboard.onNewCopy({ (item: HistoryItem) in
      XCTAssertEqual(
        Set(item.contents.map({ $0.type })),
        Set([self.tiffType.rawValue, self.stringType.rawValue])
      )
      hookExpectation.fulfill()
    })

    let item1 = NSPasteboardItem()
    item1.setString("foo", forType: .string)
    let item2 = NSPasteboardItem()
    item2.setData(image.tiffRepresentation!, forType: .tiff)

    clipboard.start()
    pasteboard.clearContents()
    pasteboard.writeObjects([item1, item2])

    waitForExpectations(timeout: 2)
  }

  func testRemovesDisabledTypes() {
    Defaults[.enabledPasteboardTypes] = [.fileURL]

    let hookExpectation = expectation(description: "Hook is called")
    clipboard.onNewCopy({ (item: HistoryItem) in
      XCTAssertEqual(item.contents.map({ $0.type }), [self.fileURLType.rawValue])
      hookExpectation.fulfill()
    })

    let item = NSPasteboardItem()
    item.setString("foo", forType: .string)
    item.setData(image.tiffRepresentation!, forType: .tiff)
    item.setData("file://foo.bar".data(using: .utf8)!, forType: .fileURL)

    clipboard.start()
    pasteboard.clearContents()
    pasteboard.writeObjects([item])

    waitForExpectations(timeout: 2)
  }

  func testRemovesDynamicTypes() {
    let hookExpectation = expectation(description: "Hook is called")
    clipboard.onNewCopy({ (item: HistoryItem) in
      XCTAssertEqual(item.contents.map({ $0.type }), [self.stringType.rawValue])
      hookExpectation.fulfill()
    })

    let item = NSPasteboardItem()
    item.setString("foo", forType: .string)
    item.setData("".data(using: .utf8)!, forType: dynamicType)

    clipboard.start()
    pasteboard.clearContents()
    pasteboard.writeObjects([item])

    waitForExpectations(timeout: 2)
  }
}
// swiftlint:enable type_body_length
