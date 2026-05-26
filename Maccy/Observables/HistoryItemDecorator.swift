import AppKit.NSScreen
import AppKit.NSWorkspace
import Defaults
import Foundation
import Observation
import Sauce

@Observable
class HistoryItemDecorator: Identifiable, Hashable {
  static func == (lhs: HistoryItemDecorator, rhs: HistoryItemDecorator) -> Bool {
    return lhs.id == rhs.id
  }

  static var previewThrottler = Throttler(minimumDelay: Double(Defaults[.previewDelay]) / 1000)
  static var previewImageSize: NSSize {
    let screenSize = NSScreen.forPopup?.visibleFrame.size ?? NSSize(width: 2048, height: 1536)
    return NSSize(width: screenSize.width * 0.75, height: screenSize.height * 0.75)
  }
  static var thumbnailImageSize: NSSize { NSSize(width: 340, height: Defaults[.imageMaxHeight]) }

  let id = UUID()

  var title: String = ""
  var attributedTitle: AttributedString?

  var isVisible: Bool = true
  var isSelected: Bool = false {
    didSet {
      if isSelected {
        Self.previewThrottler.throttle {
          Self.previewThrottler.minimumDelay = 0.2
          self.showPreview = true
        }
      } else {
        Self.previewThrottler.cancel()
        self.showPreview = false
        Task { @MainActor [weak self] in
          guard self?.isSelected == false else {
            return
          }

          self?.cleanupPreviewImage()
        }
      }
    }
  }
  var shortcuts: [KeyShortcut] = []
  var showPreview: Bool = false

  var application: String? {
    if item.universalClipboard {
      return "iCloud"
    }

    guard let bundle = item.application,
      let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle)
    else {
      return nil
    }

    return url.deletingPathExtension().lastPathComponent
  }

  var previewImageGenerationTask: Task<(), Error>?
  var thumbnailImageGenerationTask: Task<(), Error>?
  var previewImage: NSImage?
  var thumbnailImage: NSImage?
  var applicationImage: ApplicationImage

  // 10k characters seems to be more than enough on large displays
  var text: String { item.previewableText.shortened(to: 10_000) }
  var recognizedText: String { item.recognizedText ?? "" }

  var isPinned: Bool { item.pin != nil }
  var isUnpinned: Bool { item.pin == nil }

  func hash(into hasher: inout Hasher) {
    // We need to hash title and attributedTitle, so SwiftUI knows it needs to update the view if they chage
    hasher.combine(id)
    hasher.combine(title)
    hasher.combine(attributedTitle)
  }

  private(set) var item: HistoryItem

  init(_ item: HistoryItem, shortcuts: [KeyShortcut] = []) {
    self.item = item
    self.shortcuts = shortcuts
    self.title = item.title
    self.applicationImage = ApplicationImageCache.shared.getImage(item: item)

    synchronizeItemPin()
    synchronizeItemTitle()
  }

  @MainActor
  func ensureThumbnailImage() {
    guard item.hasImageData else {
      return
    }
    guard thumbnailImage == nil else {
      return
    }
    guard thumbnailImageGenerationTask == nil else {
      return
    }
    thumbnailImageGenerationTask = Task { @MainActor [weak self] in
      self?.generateThumbnailImage()
    }
  }

  @MainActor
  func ensurePreviewImage() {
    guard item.hasImageData else {
      return
    }
    guard previewImage == nil else {
      return
    }
    guard previewImageGenerationTask == nil else {
      return
    }
    previewImageGenerationTask = Task { @MainActor [weak self] in
      self?.generatePreviewImage()
    }
  }

  @MainActor
  func cleanupImages() {
    cleanupThumbnailImage()
    cleanupPreviewImage()
  }

  @MainActor
  private func cleanupThumbnailImage() {
    thumbnailImageGenerationTask?.cancel()
    thumbnailImage?.recache()
    thumbnailImageGenerationTask = nil
    thumbnailImage = nil
  }

  @MainActor
  func cleanupPreviewImage() {
    previewImageGenerationTask?.cancel()
    previewImage?.recache()
    previewImageGenerationTask = nil
    previewImage = nil
  }

  @MainActor
  private func generateThumbnailImage() {
    defer { thumbnailImageGenerationTask = nil }

    guard !Task.isCancelled,
          let image = downsampledImage(to: HistoryItemDecorator.thumbnailImageSize) else {
      return
    }

    guard !Task.isCancelled else {
      return
    }

    thumbnailImage = image.resized(to: HistoryItemDecorator.thumbnailImageSize)
  }

  @MainActor
  private func generatePreviewImage() {
    defer { previewImageGenerationTask = nil }

    guard !Task.isCancelled,
          let image = downsampledImage(to: HistoryItemDecorator.previewImageSize) else {
      return
    }

    guard !Task.isCancelled else {
      return
    }

    previewImage = image.resized(to: HistoryItemDecorator.previewImageSize)
  }

  private func downsampledImage(to size: NSSize) -> NSImage? {
    if let imageSourceURL = item.imageSourceURL {
      return autoreleasepool {
        NSImage.downsampled(contentsOf: imageSourceURL, to: size)
      }
    }

    guard let imageData = item.imageData else {
      return nil
    }

    return autoreleasepool {
      NSImage.downsampled(data: imageData, to: size)
    }
  }

  @MainActor
  func sizeImages() {
    generatePreviewImage()
    generateThumbnailImage()
  }

  func highlight(_ query: String, _ ranges: [Range<String.Index>]) {
    guard !query.isEmpty, !title.isEmpty else {
      attributedTitle = nil
      return
    }

    var attributedString = AttributedString(title.shortened(to: 500))
    for range in ranges {
      if let lowerBound = AttributedString.Index(range.lowerBound, within: attributedString),
         let upperBound = AttributedString.Index(range.upperBound, within: attributedString) {
        switch Defaults[.highlightMatch] {
        case .bold:
          attributedString[lowerBound..<upperBound].font = .bold(.body)()
        case .italic:
          attributedString[lowerBound..<upperBound].font = .italic(.body)()
        case .underline:
          attributedString[lowerBound..<upperBound].underlineStyle = .single
        default:
          attributedString[lowerBound..<upperBound].backgroundColor = .findHighlightColor
          attributedString[lowerBound..<upperBound].foregroundColor = .black
        }
      }
    }

    attributedTitle = attributedString
  }

  @MainActor
  func togglePin() {
    if item.pin != nil {
      item.pin = nil
      item.pinOrder = nil
    } else {
      let pin = HistoryItem.randomAvailablePin
      item.pin = pin
      item.pinOrder = HistoryItem.nextPinOrder
    }
  }

  private func synchronizeItemPin() {
    _ = withObservationTracking {
      item.pin
    } onChange: {
      DispatchQueue.main.async {
        if let pin = self.item.pin {
          self.shortcuts = KeyShortcut.create(character: pin)
        }
        self.synchronizeItemPin()
      }
    }
  }

  private func synchronizeItemTitle() {
    _ = withObservationTracking {
      item.title
    } onChange: {
      DispatchQueue.main.async {
        self.title = self.item.title
        self.synchronizeItemTitle()
      }
    }
  }
}
