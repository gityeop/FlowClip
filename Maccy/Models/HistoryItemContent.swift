import Foundation
import SwiftData

@Model
class HistoryItemContent {
  static let externalStorageThreshold = 512 * 1024

  var type: String = ""
  var value: Data?
  var valueFileName: String?

  @Relationship
  var item: HistoryItem?

  var resolvedValue: Data? {
    if let value {
      return value
    }

    guard let externalValueURL else {
      return nil
    }

    return try? Data(contentsOf: externalValueURL, options: .uncached)
  }

  var resolvedValueFileURL: URL? { externalValueURL }

  var hasStoredValueFile: Bool {
    guard let externalValueURL else {
      return false
    }

    return FileManager.default.fileExists(atPath: externalValueURL.path)
  }

  init(type: String, value: Data? = nil) {
    self.type = type
    setValue(value)
  }

  func setValue(_ data: Data?) {
    deleteStoredValueFile()

    guard let data else {
      value = nil
      valueFileName = nil
      return
    }

    guard data.count > Self.externalStorageThreshold else {
      value = data
      valueFileName = nil
      return
    }

    do {
      let fileName = UUID().uuidString
      let fileURL = Self.externalStorageDirectory.appending(path: fileName)
      try FileManager.default.createDirectory(at: Self.externalStorageDirectory, withIntermediateDirectories: true)
      try data.write(to: fileURL, options: .atomic)
      value = nil
      valueFileName = fileName
    } catch {
      value = data
      valueFileName = nil
    }
  }

  func deleteStoredValueFile() {
    guard let externalValueURL else {
      valueFileName = nil
      return
    }

    try? FileManager.default.removeItem(at: externalValueURL)
    valueFileName = nil
  }

  private static let externalStorageDirectory = URL.applicationSupportDirectory
    .appending(path: "Maccy/Contents", directoryHint: .isDirectory)

  private var externalValueURL: URL? {
    guard let valueFileName else {
      return nil
    }

    return Self.externalStorageDirectory.appending(path: valueFileName)
  }
}
