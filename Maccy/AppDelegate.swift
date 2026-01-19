import Defaults
import KeyboardShortcuts
import Sparkle
import SwiftUI
import Sauce
import Observation

@Observable
class QueueClipboard {
  static let shared = QueueClipboard()

  struct QueueItem: Identifiable, Hashable {
    let id = UUID()
    let item: HistoryItem
    var isPasted: Bool = false
  }

  private(set) var items: [QueueItem] = []
  var isModeActive: Bool = false

  func add(_ item: HistoryItem) {
    items.append(QueueItem(item: item))
  }

  func nextToPaste() -> HistoryItem? {
    if let index = items.firstIndex(where: { !$0.isPasted }) {
      items[index].isPasted = true
      return items[index].item
    } else if Defaults[.queueCyclePaste] && !items.isEmpty {
      // Reset all items if cycle is enabled
      for i in 0..<items.count {
        items[i].isPasted = false
      }
      items[0].isPasted = true
      return items[0].item
    }
    return nil
  }

  func clear() {
    items.removeAll()
  }
}

class QueueClipboardManager {
  static let shared = QueueClipboardManager()
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var isInternalPaste = false

  func startMonitoring() {
    stopMonitoring()
    let eventMask = (1 << CGEventType.keyDown.rawValue)
    eventTap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: CGEventMask(eventMask),
      callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
        if type == .keyDown {
          let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
          let flags = event.flags
          let isV = keyCode == Sauce.shared.keyCode(for: .v)
          let isCommand = flags.contains(.maskCommand)

          if isV && isCommand {
            if QueueClipboardManager.shared.isInternalPaste {
              QueueClipboardManager.shared.isInternalPaste = false
              return Unmanaged.passRetained(event)
            }

            if let item = QueueClipboard.shared.nextToPaste() {
              QueueClipboardManager.shared.isInternalPaste = true
              DispatchQueue.main.async {
                Clipboard.shared.copy(item)
                Clipboard.shared.paste()
              }
              return nil
            }
          }
        }
        return Unmanaged.passRetained(event)
      },
      userInfo: nil
    )
    if let eventTap = eventTap {
      runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
      CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
      CGEvent.tapEnable(tap: eventTap, enable: true)
    }
  }

  func stopMonitoring() {
    isInternalPaste = false
    if let eventTap = eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
    if let runLoopSource = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes) }
    eventTap = nil
    runLoopSource = nil
  }
}

struct QueueContentView: View {
  @State private var queue = QueueClipboard.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header
      HStack(spacing: 12) {
        Text("Queue Clipboard")
          .font(.system(size: 15, weight: .bold))

        Spacer()

        Button("Clear") {
          queue.clear()
        }
        .buttonStyle(.plain)
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(.accentColor)

        Button(action: { AppState.shared.appDelegate?.queuePanel.close() }) {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 16))
        }
        .buttonStyle(.plain)
        .foregroundColor(.secondary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)

      Divider()

      // List
      if queue.items.isEmpty {
        Spacer()
        Text("Empty Queue")
          .foregroundColor(.secondary)
          .font(.system(size: 14))
          .frame(maxWidth: .infinity, alignment: .center)
        Spacer()
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 4) {
            ForEach(queue.items) { queueItem in
              QueueItemView(queueItem: queueItem)
            }
          }
          .padding(8)
        }
      }
    }
    .frame(width: 300, height: 400)
    .background(
      ZStack {
        if #available(macOS 26.0, *) {
          GlassEffectView()
        } else {
          VisualEffectView()
        }
      }
      .ignoresSafeArea()
    )
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}

struct QueueItemView: View {
  let queueItem: QueueClipboard.QueueItem

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        if let image = queueItem.item.image {
          Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: 100, maxHeight: 60)
            .cornerRadius(4)
        }
        Text(queueItem.item.title)
          .font(.system(size: 14, weight: .medium))
          .lineLimit(2)
          .multilineTextAlignment(.leading)
      }
      Spacer()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(queueItem.isPasted ? Color.primary.opacity(0.02) : Color.primary.opacity(0.05))
    .cornerRadius(8)
    .opacity(queueItem.isPasted ? 0.4 : 1.0)
  }
}

class AppDelegate: NSObject, NSApplicationDelegate {
  var panel: FloatingPanel<ContentView>!
  var queuePanel: FloatingPanel<QueueContentView>!

  @objc
  private lazy var statusItem: NSStatusItem = {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem.behavior = .removalAllowed
    statusItem.button?.action = #selector(performStatusItemClick)
    statusItem.button?.image = Defaults[.menuIcon].image
    statusItem.button?.imagePosition = .imageLeft
    statusItem.button?.target = self
    return statusItem
  }()

  private var isStatusItemDisabled: Bool {
    Defaults[.ignoreEvents] || Defaults[.enabledPasteboardTypes].isEmpty
  }

  private var statusItemVisibilityObserver: NSKeyValueObservation?

  func applicationWillFinishLaunching(_ notification: Notification) { // swiftlint:disable:this function_body_length
    #if DEBUG
    if CommandLine.arguments.contains("enable-testing") {
      SPUUpdater(hostBundle: Bundle.main,
                 applicationBundle: Bundle.main,
                 userDriver: SPUStandardUserDriver(hostBundle: Bundle.main, delegate: nil),
                 delegate: nil)
      .automaticallyChecksForUpdates = false
    }
    #endif

    // Bridge FloatingPanel via AppDelegate.
    AppState.shared.appDelegate = self

    Clipboard.shared.onNewCopy { item in
      if QueueClipboard.shared.isModeActive {
        // Ignore items already in Maccy or those we just put for pasting
        if !item.fromMaccy {
          QueueClipboard.shared.add(item)
        }
      } else {
        History.shared.add(item)
      }
    }
    Clipboard.shared.start()

    Task {
      for await _ in Defaults.updates(.clipboardCheckInterval, initial: false) {
        Clipboard.shared.restart()
      }
    }

    statusItemVisibilityObserver = observe(\.statusItem.isVisible, options: .new) { _, change in
      if let newValue = change.newValue, Defaults[.showInStatusBar] != newValue {
        Defaults[.showInStatusBar] = newValue
      }
    }

    Task {
      for await value in Defaults.updates(.showInStatusBar) {
        statusItem.isVisible = value
      }
    }

    Task {
      for await value in Defaults.updates(.menuIcon, initial: false) {
        statusItem.button?.image = value.image
      }
    }

    synchronizeMenuIconText()
    Task {
      for await value in Defaults.updates(.showRecentCopyInMenuBar) {
        if value {
          statusItem.button?.title = AppState.shared.menuIconText
        } else {
          statusItem.button?.title = ""
        }
      }
    }

    Task {
      for await _ in Defaults.updates(.ignoreEvents) {
        statusItem.button?.appearsDisabled = isStatusItemDisabled
      }
    }

    Task {
      for await _ in Defaults.updates(.enabledPasteboardTypes) {
        statusItem.button?.appearsDisabled = isStatusItemDisabled
      }
    }
  }

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    migrateUserDefaults()
    disableUnusedGlobalHotkeys()

    panel = FloatingPanel(
      contentRect: NSRect(origin: .zero, size: Defaults[.windowSize]),
      identifier: Bundle.main.bundleIdentifier ?? "org.p0deje.Maccy",
      statusBarButton: statusItem.button,
      onClose: { AppState.shared.popup.reset() }
    ) {
      ContentView()
    }

    queuePanel = FloatingPanel(
      contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
      identifier: (Bundle.main.bundleIdentifier ?? "org.p0deje.Maccy") + ".queue",
      onClose: {
        QueueClipboard.shared.isModeActive = false
        QueueClipboardManager.shared.stopMonitoring()
      }
    ) {
      QueueContentView()
    }
    queuePanel.level = NSWindow.Level.floating // Ensure it's always on top
    queuePanel.isMovableByWindowBackground = true
    queuePanel.isMovableExternally = true
    queuePanel.closeOnResignKey = false // Keep open when focus is lost
    queuePanel.hidesOnDeactivate = false

    KeyboardShortcuts.onKeyDown(for: .queue) { [weak self] in
      self?.toggleQueue()
    }
  }

  private func toggleQueue() {
    if queuePanel.isPresented {
      queuePanel.close()
    } else {
      QueueClipboard.shared.isModeActive = true
      QueueClipboardManager.shared.startMonitoring()
      queuePanel.open(height: 400, at: PopupPosition.cursor)
    }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    panel.toggle(height: AppState.shared.popup.height)
    return true
  }

  func applicationWillTerminate(_ notification: Notification) {
    if Defaults[.clearOnQuit] {
      AppState.shared.history.clear()
    }
  }

  private func migrateUserDefaults() {
    if Defaults[.migrations]["2024-07-01-version-2"] != true {
      // Start 2.x from scratch.
      Defaults.reset(.migrations)

      // Inverse hide* configuration keys.
      Defaults[.showFooter] = !UserDefaults.standard.bool(forKey: "hideFooter")
      Defaults[.showSearch] = !UserDefaults.standard.bool(forKey: "hideSearch")
      Defaults[.showTitle] = !UserDefaults.standard.bool(forKey: "hideTitle")
      UserDefaults.standard.removeObject(forKey: "hideFooter")
      UserDefaults.standard.removeObject(forKey: "hideSearch")
      UserDefaults.standard.removeObject(forKey: "hideTitle")

      Defaults[.migrations]["2024-07-01-version-2"] = true
    }

    // The following defaults are not used in Maccy 2.x
    // and should be removed in 3.x.
    // - LaunchAtLogin__hasMigrated
    // - avoidTakingFocus
    // - saratovSeparator
    // - maxMenuItemLength
    // - maxMenuItems
  }

  @objc
  private func performStatusItemClick() {
    if let event = NSApp.currentEvent {
      let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

      if modifierFlags.contains(.option) {
        Defaults[.ignoreEvents].toggle()

        if modifierFlags.contains(.shift) {
          Defaults[.ignoreOnlyNextEvent] = Defaults[.ignoreEvents]
        }

        return
      }
    }

    panel.toggle(height: AppState.shared.popup.height, at: .statusItem)
  }

  private func synchronizeMenuIconText() {
    _ = withObservationTracking {
      AppState.shared.menuIconText
    } onChange: {
      DispatchQueue.main.async {
        if Defaults[.showRecentCopyInMenuBar] {
          self.statusItem.button?.title = AppState.shared.menuIconText
        }
        self.synchronizeMenuIconText()
      }
    }
  }

  private func disableUnusedGlobalHotkeys() {
    let names: [KeyboardShortcuts.Name] = [.delete, .pin]
    KeyboardShortcuts.disable(names)

    NotificationCenter.default.addObserver(
      forName: Notification.Name("KeyboardShortcuts_shortcutByNameDidChange"),
      object: nil,
      queue: nil
    ) { notification in
      if let name = notification.userInfo?["name"] as? KeyboardShortcuts.Name, names.contains(name) {
        KeyboardShortcuts.disable(name)
      }
    }
  }
}
