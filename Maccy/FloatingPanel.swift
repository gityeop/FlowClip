import Defaults
import SwiftUI

// An NSPanel subclass that implements floating panel traits.
// https://stackoverflow.com/questions/46023769/how-to-show-a-window-without-stealing-focus-on-macos
class CustomHostingView<Content: View>: NSHostingView<Content> {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    return true
  }
}

class FloatingPanel<Content: View>: NSPanel, NSWindowDelegate {
  var isPresented: Bool = false
  var statusBarButton: NSStatusBarButton?
  var closeOnResignKey: Bool = true
  let onClose: () -> Void
  let sizePersistenceKey: Defaults.Key<NSSize>
  let positionPersistenceKey: Defaults.Key<NSPoint>

  var isMovableExternally: Bool = false

  override var isMovable: Bool {
    get {
      if isMovableExternally {
        return true
      }
      return Defaults[.popupPosition] != .statusItem
    }
    set {}
  }

  init(
    contentRect: NSRect,
    identifier: String = "",
    statusBarButton: NSStatusBarButton? = nil,
    sizePersistenceKey: Defaults.Key<NSSize> = .windowSize,
    positionPersistenceKey: Defaults.Key<NSPoint> = .windowPosition,
    onClose: @escaping () -> Void,
    view: () -> Content
  ) {
    self.onClose = onClose
    self.sizePersistenceKey = sizePersistenceKey
    self.positionPersistenceKey = positionPersistenceKey

    super.init(
        contentRect: contentRect,
        styleMask: [.nonactivatingPanel, .resizable, .closable, .fullSizeContentView],
        backing: .buffered,
        defer: false
    )
    ignoresMouseEvents = false

    self.statusBarButton = statusBarButton
    self.identifier = NSUserInterfaceItemIdentifier(identifier)

    Defaults[sizePersistenceKey] = contentRect.size
    delegate = self

    animationBehavior = .none
    isFloatingPanel = true
    level = .statusBar
    collectionBehavior = [.auxiliary, .stationary, .moveToActiveSpace, .fullScreenAuxiliary]
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    isMovableByWindowBackground = true
    hidesOnDeactivate = false
    backgroundColor = .clear
    titlebarSeparatorStyle = .none

    // Hide all traffic light buttons
    standardWindowButton(.zoomButton)?.isHidden = true


     contentView = CustomHostingView(
      rootView: view()
        // The safe area is ignored because the title bar still interferes with the geometry
        .ignoresSafeArea()
        .gesture(DragGesture()
          .onEnded { _ in
            self.saveWindowPosition()
        })
    )
    contentView?.layer?.cornerRadius = Popup.cornerRadius + Popup.horizontalPadding
  }

  func toggle(height: CGFloat, at popupPosition: PopupPosition = Defaults[.popupPosition]) {
    if isPresented {
      close()
    } else {
      open(height: height, at: popupPosition)
    }
  }

  func open(height: CGFloat, at popupPosition: PopupPosition = Defaults[.popupPosition], makeKey: Bool = true) {
    setContentSize(NSSize(width: frame.width, height: min(height, Defaults[sizePersistenceKey].height)))
    setFrameOrigin(popupPosition.origin(size: frame.size, statusBarButton: statusBarButton))
    orderFrontRegardless()
    if makeKey {
      self.makeKey()
    }
    isPresented = true

    if popupPosition == .statusItem {
      DispatchQueue.main.async {
        self.statusBarButton?.isHighlighted = true
      }
    }
  }

  func verticallyResize(to newHeight: CGFloat) {
    var newSize = Defaults[sizePersistenceKey]
    newSize.height = min(newHeight, newSize.height)

    var newOrigin = frame.origin
    newOrigin.y += (frame.height - newSize.height)

    NSAnimationContext.runAnimationGroup { (context) in
      context.duration = 0.2
      animator().setFrame(NSRect(origin: newOrigin, size: newSize), display: true)
    }
  }

  func saveWindowPosition() {
    if let screenFrame = screen?.visibleFrame {
      let anchorX = frame.minX + frame.width / 2 - screenFrame.minX
      let anchorY = frame.maxY - screenFrame.minY
      Defaults[positionPersistenceKey] = NSPoint(x: anchorX / screenFrame.width, y: anchorY / screenFrame.height)
    }
  }

  func saveWindowFrame(frame: NSRect) {
    Defaults[sizePersistenceKey] = frame.size
    saveWindowPosition()
  }

  func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
    if inLiveResize {
      saveWindowFrame(frame: NSRect(origin: frame.origin, size: frameSize))
    }

    return frameSize
  }

  // Close automatically when out of focus, e.g. outside click.
  override func resignKey() {
    super.resignKey()
    // Don't hide if confirmation is shown.
    if closeOnResignKey && NSApp.alertWindow == nil {
      close()
    }
  }

  override func close() {
    super.close()
    isPresented = false
    statusBarButton?.isHighlighted = false
    onClose()
  }

  // Allow text inputs inside the panel can receive focus
  override var canBecomeKey: Bool {
    return true
  }
}
