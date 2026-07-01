import AppKit.NSEvent
import Defaults
import Foundation

enum PopupPosition: String, CaseIterable, Identifiable, CustomStringConvertible, Defaults.Serializable {
  case cursor
  case statusItem
  case window
  case center
  case lastPosition

  var id: Self { self }

  var description: String {
    switch self {
    case .cursor:
      return NSLocalizedString("PopupAtCursor", tableName: "AppearanceSettings", comment: "")
    case .statusItem:
      return NSLocalizedString("PopupAtMenuBarIcon", tableName: "AppearanceSettings", comment: "")
    case .window:
      return NSLocalizedString("PopupAtWindowCenter", tableName: "AppearanceSettings", comment: "")
    case .center:
      return NSLocalizedString("PopupAtScreenCenter", tableName: "AppearanceSettings", comment: "")
    case .lastPosition:
      return NSLocalizedString("PopupAtLastPosition", tableName: "AppearanceSettings", comment: "")
    }
  }

  // swiftlint:disable:next cyclomatic_complexity
  func origin(
    size: NSSize,
    statusBarButton: NSStatusBarButton?,
    positionPersistenceKey: Defaults.Key<NSPoint> = .windowPosition
  ) -> NSPoint {
    switch self {
    case .center:
      if let frame = NSScreen.forPopup?.visibleFrame {
        return NSRect.centered(ofSize: size, in: frame).origin
      }
    case .window:
      if let frame = NSWorkspace.shared.frontmostApplication?.windowFrame {
        return NSRect.centered(ofSize: size, in: frame).origin
      }
    case .statusItem:
      guard let statusBarButton else {
        preconditionFailure("Missing status bar button for menu icon popup position.")
      }
      guard let statusBarWindow = statusBarButton.window else {
        preconditionFailure("Missing status bar window for menu icon popup position.")
      }
      guard let screen = statusBarWindow.screen else {
        preconditionFailure("Missing status bar screen for menu icon popup position.")
      }

      let rectInWindow = statusBarButton.convert(statusBarButton.bounds, to: nil)
      let screenRect = statusBarWindow.convertToScreen(rectInWindow)
      let screenFrame = screen.visibleFrame
      var topLeftPoint = NSPoint(
        x: screenRect.minX,
        y: screenRect.minY - size.height
      )

      if topLeftPoint.x < screenFrame.minX {
        topLeftPoint.x = screenFrame.minX
      }
      if topLeftPoint.x + size.width > screenFrame.maxX {
        topLeftPoint.x = screenFrame.maxX - size.width
      }

      return topLeftPoint
    case .lastPosition:
      if let frame = NSScreen.forPopup?.visibleFrame {
        let relativePos = Defaults[positionPersistenceKey]
        let anchorX = frame.minX + frame.width * relativePos.x
        let anchorY = frame.minY + frame.height * relativePos.y
        // Anchor is top middle of frame
        return NSPoint(x: anchorX - size.width / 2, y: anchorY - size.height)
      }
    default:
      break
    }

    var point = NSEvent.mouseLocation
    point.y -= size.height
    
    // Clamp to screen
    if let screen = NSScreen.main {
      let screenFrame = screen.visibleFrame
      if point.x + size.width > screenFrame.maxX {
        point.x = screenFrame.maxX - size.width
      }
      if point.y < screenFrame.minY {
        point.y = screenFrame.minY
      }
      if point.y + size.height > screenFrame.maxY {
        point.y = screenFrame.maxY - size.height
      }
    }
    
    return point
  }
}
