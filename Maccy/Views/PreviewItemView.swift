import AppKit.NSScreen
import KeyboardShortcuts
import SwiftUI

struct PreviewItemView: View {
  weak var item: HistoryItemDecorator?

  var body: some View {
    if let item = item {
      VStack(alignment: .leading, spacing: 0) {
        if let image = item.previewImage {
          let frame = previewFrame(for: image)
          Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: frame.width, height: frame.height)
            .clipShape(.rect(cornerRadius: 5))
        } else if item.item.hasImageData {
          ProgressView()
            .frame(width: loadingPreviewSize.width, height: loadingPreviewSize.height)
        } else {
          ScrollView {
            WrappingTextView {
              Text(item.text)
                .font(.body)
            }
          }
        }

        Divider()
          .padding(.vertical)

        if let application = item.application {
          HStack(spacing: 3) {
            Text("Application", tableName: "PreviewItemView")
            Image(nsImage: item.applicationImage.nsImage)
              .resizable()
              .frame(width: 11, height: 11)
            Text(application)
          }
        }

        HStack(spacing: 3) {
          Text("FirstCopyTime", tableName: "PreviewItemView")
          Text(item.item.firstCopiedAt, style: .date)
          Text(item.item.firstCopiedAt, style: .time)
        }

        HStack(spacing: 3) {
          Text("LastCopyTime", tableName: "PreviewItemView")
          Text(item.item.lastCopiedAt, style: .date)
          Text(item.item.lastCopiedAt, style: .time)
        }

        HStack(spacing: 3) {
          Text("NumberOfCopies", tableName: "PreviewItemView")
          Text(String(item.item.numberOfCopies))
        }
        .padding(.bottom)

        if let pinKey = KeyboardShortcuts.Shortcut(name: .pin) {
          Text(
            NSLocalizedString("PinKey", tableName: "PreviewItemView", comment: "")
              .replacingOccurrences(of: "{pinKey}", with: pinKey.description)
          )
        }

        if let deleteKey = KeyboardShortcuts.Shortcut(name: .delete) {
          Text(
            NSLocalizedString("DeleteKey", tableName: "PreviewItemView", comment: "")
              .replacingOccurrences(of: "{deleteKey}", with: deleteKey.description)
          )
        }
      }
      .controlSize(.small)
      .padding()
    }
  }

  private var loadingPreviewSize: NSSize {
    let maxSize = maxPreviewSize
    return NSSize(width: maxSize.width * 0.5, height: maxSize.height * 0.5)
  }

  private var maxPreviewSize: NSSize {
    let screenSize = NSScreen.forPopup?.visibleFrame.size ?? NSSize(width: 2048, height: 1536)
    return NSSize(width: screenSize.width * 0.75, height: screenSize.height * 0.75)
  }

  private func previewFrame(for image: NSImage) -> NSSize {
    let maxSize = maxPreviewSize
    guard image.size.width > 0, image.size.height > 0 else {
      return loadingPreviewSize
    }

    let ratio = min(maxSize.width / image.size.width, maxSize.height / image.size.height)
    let fittedRatio = min(ratio, 1)

    return NSSize(width: image.size.width * fittedRatio, height: image.size.height * fittedRatio)
  }
}
