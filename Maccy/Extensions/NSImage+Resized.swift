import AppKit.NSImage
import ImageIO

// Based on https://stackoverflow.com/questions/73062803/resizing-nsimage-keeping-aspect-ratio-reducing-the-image-size-while-trying-to-sc.
extension NSImage {
  static func downsampled(data: Data, to maxSize: NSSize) -> NSImage? {
    let sourceOptions = [
      kCGImageSourceShouldCache: false
    ] as CFDictionary

    guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
      return nil
    }

    return downsampled(source: source, to: maxSize) {
      NSImage(data: data)?.resized(to: maxSize)
    }
  }

  static func downsampled(contentsOf url: URL, to maxSize: NSSize) -> NSImage? {
    let sourceOptions = [
      kCGImageSourceShouldCache: false
    ] as CFDictionary

    guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
      return nil
    }

    return downsampled(source: source, to: maxSize) {
      NSImage(contentsOf: url)?.resized(to: maxSize)
    }
  }

  private static func downsampled(
    source: CGImageSource,
    to maxSize: NSSize,
    fallback: () -> NSImage?
  ) -> NSImage? {
    guard let originalSize = imageSize(from: source),
          let targetSize = fittedSize(originalSize: originalSize, maxSize: maxSize) else {
      return fallback()
    }

    // Don't attempt to size up.
    guard targetSize.height < originalSize.height || targetSize.width < originalSize.width else {
      return fallback()
    }

    let maxPixelSize = max(targetSize.width, targetSize.height)
    let thumbnailOptions = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
    ] as CFDictionary

    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
      return fallback()
    }

    return NSImage(cgImage: cgImage, size: targetSize)
  }

  func resized(to maxSize: NSSize) -> NSImage {
    guard let newSize = Self.fittedSize(originalSize: size, maxSize: maxSize) else {
      return self
    }

    // Don't attempt to size up.
    if newSize.height >= size.height && newSize.width >= size.width {
      return self
    }

    let resizedImage = NSImage(size: newSize)
    resizedImage.lockFocus()
    defer { resizedImage.unlockFocus() }

    if let context = NSGraphicsContext.current {
      context.imageInterpolation = .high
    }

    self.draw(
      in: NSRect(origin: .zero, size: newSize),
      from: NSRect(origin: .zero, size: size),
      operation: .copy,
      fraction: 1
    )

    return resizedImage
  }

  private static func imageSize(from source: CGImageSource) -> NSSize? {
    guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
          let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
      return nil
    }

    return NSSize(width: CGFloat(truncating: width), height: CGFloat(truncating: height))
  }

  private static func fittedSize(originalSize: NSSize, maxSize: NSSize) -> NSSize? {
    guard originalSize.width > 0, originalSize.height > 0, maxSize.width > 0, maxSize.height > 0 else {
      return nil
    }

    let ratioX = maxSize.width / originalSize.width
    let ratioY = maxSize.height / originalSize.height
    let ratio = min(ratioX, ratioY)

    return NSSize(width: originalSize.width * ratio, height: originalSize.height * ratio)
  }
}
