import AppKit
import Defaults

enum QueueSeparator: String, CaseIterable, Identifiable, CustomStringConvertible, Defaults.Serializable {
  case none
  case space
  case newline
  case comma
  case custom

  static let presetCount = 9
  static let defaultPresetSlots = [", "] + Array(repeating: "", count: presetCount - 1)
  static let defaultPresetModes = Array(repeating: QueueSeparator.custom.rawValue, count: presetCount)

  var id: Self { self }

  var description: String {
    switch self {
    case .none:
      return NSLocalizedString("None", tableName: "GeneralSettings", comment: "")
    case .space:
      return NSLocalizedString("Space", tableName: "GeneralSettings", comment: "")
    case .newline:
      return NSLocalizedString("Newline", tableName: "GeneralSettings", comment: "")
    case .comma:
      return NSLocalizedString("Comma", tableName: "GeneralSettings", comment: "")
    case .custom:
      return NSLocalizedString("Custom", tableName: "GeneralSettings", comment: "")
    }
  }

  var value: String? {
    switch self {
    case .none:
      return nil
    case .space:
      return " "
    case .newline:
      return "\n"
    case .comma:
      return ","
    case .custom:
      return Self.effectiveValue(for: .custom, rawPresetValue: Defaults[.customQueueSeparator])
    }
  }

  static func normalizedPresetSlots(_ presets: [String]) -> [String] {
    var normalized = Array(presets.prefix(presetCount))
    if normalized.count < presetCount {
      normalized.append(contentsOf: repeatElement("", count: presetCount - normalized.count))
    }
    return normalized
  }

  static func normalizedPresetModes(_ presetModes: [String]) -> [String] {
    var normalized = Array(presetModes.prefix(presetCount))
    if normalized.count < presetCount {
      normalized.append(contentsOf: defaultPresetModes.dropFirst(normalized.count))
    }

    return normalized.map { QueueSeparator(rawValue: $0)?.rawValue ?? QueueSeparator.custom.rawValue }
  }

  static func normalizedPresetIndex(_ index: Int, presets: [String]? = nil) -> Int {
    let slotCount = presets?.count ?? presetCount
    guard slotCount > 0 else {
      return 0
    }

    return min(max(index, 0), slotCount - 1)
  }

  static func currentPresetNumber() -> Int {
    normalizedPresetIndex(Defaults[.queueActiveSeparatorPresetIndex]) + 1
  }

  static func presetMode(at index: Int, presetModes: [String]? = nil) -> QueueSeparator {
    let normalizedModes = normalizedPresetModes(presetModes ?? Defaults[.queueSeparatorPresetModes])
    let normalizedIndex = normalizedPresetIndex(index, presets: normalizedModes)
    return QueueSeparator(rawValue: normalizedModes[normalizedIndex]) ?? .custom
  }

  static func currentPresetMode() -> QueueSeparator {
    let presets = normalizedPresetSlots(Defaults[.queueSeparatorPresets])
    let index = normalizedPresetIndex(Defaults[.queueActiveSeparatorPresetIndex], presets: presets)
    return presetMode(at: index)
  }

  static func currentPresetRawValue() -> String {
    let presets = normalizedPresetSlots(Defaults[.queueSeparatorPresets])
    let index = normalizedPresetIndex(Defaults[.queueActiveSeparatorPresetIndex], presets: presets)
    return presets[index]
  }

  static func currentPresetValue() -> String? {
    effectiveValue(for: currentPresetMode(), rawPresetValue: currentPresetRawValue())
  }

  static func currentPresetPreview(maxLength: Int = 4) -> String {
    samplePreview(
      for: currentPresetMode(),
      rawPresetValue: currentPresetRawValue(),
      maxLength: maxLength
    )
  }

  static func samplePreview(for separator: String, maxLength: Int = 4) -> String {
    let visibleSeparator = visiblePreview(for: decodeEscapes(separator), maxLength: maxLength)
    return "A\(visibleSeparator.isEmpty ? "∅" : visibleSeparator)B"
  }

  static func migrateLegacyPresetModes(
    _ presetModes: [String],
    presetValues: [String],
    activePresetIndex: Int,
    currentSeparator: QueueSeparator
  ) -> [String] {
    let normalizedPresetValues = normalizedPresetSlots(presetValues)
    var migratedModes = normalizedPresetModes(presetModes)

    for index in normalizedPresetValues.indices where !normalizedPresetValues[index].isEmpty {
      migratedModes[index] = QueueSeparator.custom.rawValue
    }

    let normalizedActiveIndex = normalizedPresetIndex(activePresetIndex, presets: normalizedPresetValues)
    migratedModes[normalizedActiveIndex] = currentSeparator.rawValue
    return migratedModes
  }

  @discardableResult
  static func selectPreset(_ index: Int) -> Int {
    let presets = normalizedPresetSlots(Defaults[.queueSeparatorPresets])
    let normalizedIndex = normalizedPresetIndex(index, presets: presets)
    let presetMode = presetMode(at: normalizedIndex)

    Defaults[.queueActiveSeparatorPresetIndex] = normalizedIndex
    Defaults[.customQueueSeparator] = presets[normalizedIndex]
    Defaults[.queueSeparator] = presetMode
    return normalizedIndex
  }

  @discardableResult
  static func cycleCurrentPreset() -> Int {
    let presets = normalizedPresetSlots(Defaults[.queueSeparatorPresets])
    let presetModes = normalizedPresetModes(Defaults[.queueSeparatorPresetModes])
    let cycleTargets = presets.indices.filter {
      isPresetConfigured(
        mode: presetMode(at: $0, presetModes: presetModes),
        rawPresetValue: presets[$0]
      )
    }

    guard let firstTarget = cycleTargets.first else {
      return selectPreset(0)
    }

    let currentIndex = normalizedPresetIndex(Defaults[.queueActiveSeparatorPresetIndex], presets: presets)
    let nextIndex: Int

    if let currentPosition = cycleTargets.firstIndex(of: currentIndex) {
      let nextPosition = (currentPosition + 1) % cycleTargets.count
      nextIndex = cycleTargets[nextPosition]
    } else {
      nextIndex = firstTarget
    }

    return selectPreset(nextIndex)
  }

  private static func decodeEscapes(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\\n", with: "\n")
      .replacingOccurrences(of: "\\t", with: "\t")
      .replacingOccurrences(of: "\\r", with: "\r")
  }

  private static func effectiveValue(for separator: QueueSeparator, rawPresetValue: String) -> String? {
    switch separator {
    case .none:
      return nil
    case .space:
      return " "
    case .newline:
      return "\n"
    case .comma:
      return ","
    case .custom:
      let decodedValue = decodeEscapes(rawPresetValue)
      return decodedValue.isEmpty ? nil : decodedValue
    }
  }

  private static func isPresetConfigured(mode: QueueSeparator, rawPresetValue: String) -> Bool {
    switch mode {
    case .custom:
      return !rawPresetValue.isEmpty
    default:
      return true
    }
  }

  private static func samplePreview(
    for separator: QueueSeparator,
    rawPresetValue: String,
    maxLength: Int
  ) -> String {
    let visibleSeparator = visiblePreview(
      for: effectiveValue(for: separator, rawPresetValue: rawPresetValue) ?? "",
      maxLength: maxLength
    )
    return "A\(visibleSeparator.isEmpty ? "∅" : visibleSeparator)B"
  }

  private static func visiblePreview(for separator: String, maxLength: Int) -> String {
    let preview = separator
      .replacingOccurrences(of: "\n", with: "⏎")
      .replacingOccurrences(of: "\t", with: "⇥")
      .replacingOccurrences(of: "\r", with: "↩")

    let limit = max(1, maxLength)
    guard preview.count > limit else {
      return preview
    }

    return String(preview.prefix(limit - 1)) + "…"
  }
}

struct StorageType {
  static let files = StorageType(types: [.fileURL])
  static let images = StorageType(types: [.png, .tiff])
  static let text = StorageType(types: [.html, .rtf, .string])
  static let all = StorageType(types: files.types + images.types + text.types)

  var types: [NSPasteboard.PasteboardType]
}

extension Defaults.Keys {
  static let clearOnQuit = Key<Bool>("clearOnQuit", default: false)
  static let clearSystemClipboard = Key<Bool>("clearSystemClipboard", default: false)
  static let clipboardCheckInterval = Key<Double>("clipboardCheckInterval", default: 0.5)
  static let customQueueSeparator = Key<String>("customQueueSeparator", default: ", ")
  static let queueSeparatorPresets = Key<[String]>(
    "queueSeparatorPresets",
    default: QueueSeparator.defaultPresetSlots
  )
  static let queueSeparatorPresetModes = Key<[String]>(
    "queueSeparatorPresetModes",
    default: QueueSeparator.defaultPresetModes
  )
  static let queueActiveSeparatorPresetIndex = Key<Int>("queueActiveSeparatorPresetIndex", default: 0)
  static let enabledPasteboardTypes = Key<Set<NSPasteboard.PasteboardType>>(
    "enabledPasteboardTypes", default: Set(StorageType.all.types)
  )
  static let highlightMatch = Key<HighlightMatch>("highlightMatch", default: .bold)
  static let ignoreAllAppsExceptListed = Key<Bool>("ignoreAllAppsExceptListed", default: false)
  static let ignoreEvents = Key<Bool>("ignoreEvents", default: false)
  static let ignoreOnlyNextEvent = Key<Bool>("ignoreOnlyNextEvent", default: false)
  static let ignoreRegexp = Key<[String]>("ignoreRegexp", default: [])
  static let ignoredApps = Key<[String]>("ignoredApps", default: [])
  static let ignoredPasteboardTypes = Key<Set<String>>(
    "ignoredPasteboardTypes",
    default: Set([
      "Pasteboard generator type",
      "com.agilebits.onepassword",
      "com.typeit4me.clipping",
      "de.petermaurer.TransientPasteboardType",
      "net.antelle.keeweb"
    ])
  )
  static let imageMaxHeight = Key<Int>("imageMaxHeight", default: 40)
  static let lastReviewRequestedAt = Key<Date>("lastReviewRequestedAt", default: Date.now)
  static let menuIcon = Key<MenuIcon>("menuIcon", default: .maccy)
  static let migrations = Key<[String: Bool]>("migrations", default: [:])
  static let numberOfUsages = Key<Int>("numberOfUsages", default: 0)
  static let pasteByDefault = Key<Bool>("pasteByDefault", default: false)
  static let pinTo = Key<PinsPosition>("pinTo", default: .top)
  static let popupPosition = Key<PopupPosition>("popupPosition", default: .cursor)
  static let popupScreen = Key<Int>("popupScreen", default: 0)
  static let queueCyclePaste = Key<Bool>("queueCyclePaste", default: false)
  static let queuePasteLifo = Key<Bool>("queuePasteLifo", default: true)
  static let queueAutoSplitText = Key<Bool>("queueAutoSplitText", default: false)
  static let queueSeparator = Key<QueueSeparator>("queueSeparator", default: .custom)
  static let previewDelay = Key<Int>("previewDelay", default: 1500)
  static let removeFormattingByDefault = Key<Bool>("removeFormattingByDefault", default: false)
  static let searchMode = Key<Search.Mode>("searchMode", default: .exact)
  static let showFooter = Key<Bool>("showFooter", default: true)
  static let showInStatusBar = Key<Bool>("showInStatusBar", default: true)
  static let showRecentCopyInMenuBar = Key<Bool>("showRecentCopyInMenuBar", default: false)
  static let showSearch = Key<Bool>("showSearch", default: true)
  static let searchVisibility = Key<SearchVisibility>("searchVisibility", default: .always)
  static let showSpecialSymbols = Key<Bool>("showSpecialSymbols", default: true)
  static let showTitle = Key<Bool>("showTitle", default: true)
  static let size = Key<Int>("historySize", default: 200)
  static let sortBy = Key<Sorter.By>("sortBy", default: .lastCopiedAt)
  static let suppressClearAlert = Key<Bool>("suppressClearAlert", default: false)
  static let windowSize = Key<NSSize>("windowSize", default: NSSize(width: 450, height: 800))
  static let queueWindowSize = Key<NSSize>("queueWindowSize", default: NSSize(width: 260, height: 360))
  static let windowPosition = Key<NSPoint>("windowPosition", default: NSPoint(x: 0.5, y: 0.8))
  static let queueWindowPosition = Key<NSPoint>("queueWindowPosition", default: NSPoint(x: 0.5, y: 0.5))
  static let showApplicationIcons = Key<Bool>("showApplicationIcons", default: false)
}
