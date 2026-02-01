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
    let useLifo = Defaults[.queuePasteLifo]

    // Choose index depending on FIFO / LIFO preference
    if let index = (useLifo ? items.lastIndex(where: { !$0.isPasted }) : items.firstIndex(where: { !$0.isPasted })) {
      items[index].isPasted = true

      // If this was the last item and cycle is on, reset immediately for visual feedback
      if Defaults[.queueCyclePaste] && items.allSatisfy({ $0.isPasted }) {
        for i in 0..<items.count {
          items[i].isPasted = false
        }
      }

      return items[index].item
    } else if Defaults[.queueCyclePaste] && !items.isEmpty {
      // It handles pasting when they were already all dimmed.
      // Reset and pick newest or oldest depending on LIFO setting.
      for i in 0..<items.count {
        items[i].isPasted = false
      }
      let chosenIndex = useLifo ? (items.count - 1) : 0
      items[chosenIndex].isPasted = true
      return items[chosenIndex].item
    }
    return nil
  }

  func remove(id: UUID) {
    items.removeAll(where: { $0.id == id })
  }

  func clear() {
    items.removeAll()
  }
}

class QueueClipboardManager {
  static let shared = QueueClipboardManager()
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  fileprivate var isInternalPaste = false

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
          let isC = keyCode == Sauce.shared.keyCode(for: .c)
          let isCommand = flags.contains(.maskCommand)

          if isC && isCommand {
            // If Maccy is active, pass focus to the background app and re-trigger copy
            if NSApp.isActive {
              NSApp.deactivate()
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let source = CGEventSource(stateID: .hidSystemState)
                let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true)
                keyDown?.flags = .maskCommand
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: false)
                keyUp?.flags = .maskCommand
                keyDown?.post(tap: .cghidEventTap)
                keyUp?.post(tap: .cghidEventTap)
              }
              return nil
            }
          }

          if isV && isCommand {
            if QueueClipboardManager.shared.isInternalPaste {
              QueueClipboardManager.shared.isInternalPaste = false
              return Unmanaged.passRetained(event)
            }
            
            // If Maccy is active, deactivate first so we paste into the target app
            if NSApp.isActive {
               NSApp.deactivate()
            }

            if let item = QueueClipboard.shared.nextToPaste() {
              QueueClipboardManager.shared.isInternalPaste = true
              DispatchQueue.main.asyncAfter(deadline: .now() + (NSApp.isActive ? 0.2 : 0.0)) { 
                // Add extra delay if we just deactivated
                Clipboard.shared.copy(item)
                Clipboard.shared.paste()

                // Paste separator if configured
                let separator = Defaults[.queueSeparator]
                if let separatorValue = separator.value {
                  // Small delay to ensure the main item is pasted first
                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    QueueClipboardManager.shared.isInternalPaste = true
                    Clipboard.shared.copy(separatorValue, fromMaccy: true)
                    Clipboard.shared.paste()
                  }
                }
              }
              return nil
            } else {
              // Queue is active but exhausted (and cycle is off)
              // Block the original Command + V and beep
              NSSound.beep()
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
    Accessibility.check()
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
      contentRect: NSRect(origin: .zero, size: Defaults[.queueWindowSize]),
      identifier: (Bundle.main.bundleIdentifier ?? "org.p0deje.Maccy") + ".queue",
      sizePersistenceKey: .queueWindowSize,
      positionPersistenceKey: .queueWindowPosition,
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
    
    KeyboardShortcuts.onKeyDown(for: .queueClear) {
      QueueClipboard.shared.clear()
    }
    
    KeyboardShortcuts.onKeyDown(for: .queuePasteAll) {
       guard !QueueClipboard.shared.items.isEmpty else { return }
       
       let separator = Defaults[.queueSeparator].value ?? ""
       let itemsToPaste = Defaults[.queuePasteLifo] ? QueueClipboard.shared.items.reversed() : QueueClipboard.shared.items
       let itemsText = itemsToPaste.compactMap { $0.item.previewableText }.joined(separator: separator) + separator
       
       QueueClipboardManager.shared.isInternalPaste = true
       Clipboard.shared.copy(itemsText, fromMaccy: true)
       Clipboard.shared.paste()
    }
  }

  private func toggleQueue() {
    guard Accessibility.allowed else {
      let alert = NSAlert()
      alert.messageText = NSLocalizedString("AccessibilityPermissionRequired", comment: "")
      alert.informativeText = NSLocalizedString("AccessibilityPermissionRequiredMessage", comment: "")
      alert.addButton(withTitle: NSLocalizedString("OpenSystemSettings", comment: ""))
      alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
      
      if alert.runModal() == .alertFirstButtonReturn {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
          NSWorkspace.shared.open(url)
        }
        Accessibility.check() // Trigger system prompt if needed
      }
      return
    }

    if queuePanel.isPresented {
      queuePanel.close()
    } else {
      QueueClipboard.shared.isModeActive = true
      QueueClipboardManager.shared.startMonitoring()
      queuePanel.open(height: Defaults[.queueWindowSize].height, at: PopupPosition.cursor, makeKey: false)
    }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    panel.toggle(height: AppState.shared.popup.height)
    return true
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
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

struct QueueContentView: View {
  @State var queue = QueueClipboard.shared
  @Default(.queueCyclePaste) var queueCyclePaste
  @Default(.queuePasteLifo) var queuePasteLifo
  @State private var isHoveringClose = false

  var body: some View {
    ZStack {
      VStack(alignment: .leading, spacing: 0) {
        // Header
        ZStack {
          Text("Queue Clipboard")
            .font(.system(size: 13, weight: .semibold))
            .frame(maxWidth: .infinity, alignment: .center)
            
          HStack {
            Button(action: { AppState.shared.appDelegate?.queuePanel.close() }) {
              Image(systemName: isHoveringClose ? "xmark.circle.fill" : "circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .onHover { inside in
              isHoveringClose = inside
              if inside {
                NSCursor.pointingHand.push()
              } else {
                NSCursor.pop()
              }
            }
            
            Spacer()
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))

        // List
        if queue.items.isEmpty {
          Spacer()
          Text("Empty Queue")
            .foregroundColor(.secondary)
            .font(.system(size: 12))
            .frame(maxWidth: .infinity, alignment: .center)
          Spacer()
        } else {
          ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
              ForEach(Array(queue.items.enumerated()), id: \.element.id) { index, queueItem in
                QueueItemView(queueItem: queueItem)
              }
            }
            // Add padding at bottom so last item isn't covered by floating bar
            .padding(.bottom, 60)
          }
          .scrollIndicators(.hidden)
        }
      }
      
      // Floating Controls (Bottom)
      VStack {
        Spacer()
        HStack {
          // Left Group: Cycle + LIFO/FIFO
          HStack(spacing: 12) {
            Button(action: { queueCyclePaste.toggle() }) {
              Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 14))
                .foregroundColor(queueCyclePaste ? .accentColor : .primary)
            }
            .buttonStyle(.plain)
            .help("Cycle Paste")
            
            Divider()
              .frame(height: 12)
            
            Button(action: { queuePasteLifo.toggle() }) {
              Text(queuePasteLifo ? "LIFO" : "FIFO")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .frame(width: 30) // Fixed width to prevent jitter
            .help("Toggle Paste Order")
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(.regularMaterial, in: Capsule())
          .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
          .overlay(
            Capsule()
              .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
          )
          
          Spacer()
          
          // Right Button: Clear
          Button(action: { queue.clear() }) {
            Image(systemName: "trash")
              .font(.system(size: 14))
              .foregroundColor(.red.opacity(0.8))
          }
          .buttonStyle(.plain)
          .padding(8)
          .background(.regularMaterial, in: Circle())
          .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
          .overlay(
            Circle()
              .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
          )
          .help("Clear Queue")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
      }
    }
    .frame(minWidth: 260, minHeight: 360)
    .background(
      ZStack {
        VisualEffectView()
      }
      .ignoresSafeArea()
    )
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}

struct QueueItemView: View {
  let queueItem: QueueClipboard.QueueItem
  @State private var isHovering = false

  var body: some View {
    ZStack(alignment: .trailing) {
      Button(action: {
        // 1. Ensure focus goes back to the previous app
        NSApp.deactivate()
        
        // 2. Prepare for internal paste bypass
        QueueClipboardManager.shared.isInternalPaste = true
        
        // 3. Copy the item
        Clipboard.shared.copy(queueItem.item)
        
        // 4. Paste with a slight delay to allow focus switch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          Clipboard.shared.paste()
        }
      }) {
        HStack(alignment: .top, spacing: 10) {
          VStack(alignment: .leading, spacing: 2) {
            if let image = queueItem.item.image {
              Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 80, maxHeight: 45)
                .cornerRadius(4)
            }
            Text(queueItem.item.title)
              .font(.system(size: 12, weight: .medium))
              .lineLimit(2)
              .multilineTextAlignment(.leading)
          }
          Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHovering ? Color.primary.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      
      if isHovering {
        Button(action: {
          QueueClipboard.shared.remove(id: queueItem.id)
        }) {
          Image(systemName: "xmark")
            .foregroundColor(.secondary)
            .font(.system(size: 9, weight: .bold))
        }
        .buttonStyle(.plain)
        .transition(.opacity)
        .padding(.trailing, 10)
      }
    }
    .opacity(queueItem.isPasted ? 0.3 : 1.0)
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.1)) {
        isHovering = hovering
      }
    }
  }
}
