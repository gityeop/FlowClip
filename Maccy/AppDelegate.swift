import Defaults
import KeyboardShortcuts
import Sparkle
import SwiftUI
import Sauce
import Observation
import UniformTypeIdentifiers

private struct QueueControlDividerMidpointsPreferenceKey: PreferenceKey {
  static var defaultValue: [CGFloat] = []

  static func reduce(value: inout [CGFloat], nextValue: () -> [CGFloat]) {
    value.append(contentsOf: nextValue())
  }
}

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

  func addFromClipboard(_ item: HistoryItem) {
    guard Defaults[.queueAutoSplitText] else {
      add(item)
      return
    }

    let splitItems = QueueTextSplitter.split(item: item)
    guard splitItems.count > 1 else {
      add(item)
      return
    }

    item.contents.forEach { content in
      content.deleteStoredValueFile()
    }

    splitItems.forEach { splitText in
      let queueItem = HistoryItem(contents: [
        HistoryItemContent(
          type: NSPasteboard.PasteboardType.string.rawValue,
          value: Data(splitText.utf8)
        )
      ])
      queueItem.application = item.application
      queueItem.title = queueItem.generateTitle()
      add(queueItem)
    }
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
    let removedItems = items.filter { $0.id == id }
    removedItems.forEach(cleanup)
    items.removeAll(where: { $0.id == id })
  }

  func move(from source: IndexSet, to destination: Int) {
    items.move(fromOffsets: source, toOffset: destination)
  }

  func move(itemWithID sourceID: UUID, beforeItemWithID destinationID: UUID) {
    guard sourceID != destinationID,
          let sourceIndex = items.firstIndex(where: { $0.id == sourceID }),
          let destinationIndex = items.firstIndex(where: { $0.id == destinationID }) else {
      return
    }

    let newOffset = destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
    items.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: newOffset)
  }

  func moveToEnd(itemWithID id: UUID) {
    guard let sourceIndex = items.firstIndex(where: { $0.id == id }) else {
      return
    }

    items.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: items.count)
  }

  func clear() {
    items.forEach(cleanup)
    items.removeAll()
  }

  private func cleanup(_ queueItem: QueueItem) {
    queueItem.item.contents.forEach { content in
      content.deleteStoredValueFile()
    }
  }
}

enum QueueTextSplitter {
  static func split(item: HistoryItem) -> [String] {
    guard let text = extractedText(from: item) else {
      return []
    }

    return split(text: text)
  }

  static func split(text: String) -> [String] {
    let normalized = normalize(text)
    guard normalized.contains("\n") else {
      return [normalized]
    }

    let lines = normalized
      .components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    return lines.count > 1 ? lines : [normalized]
  }

  private static func extractedText(from item: HistoryItem) -> String? {
    if let text = item.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
      return text
    }

    if !item.fileURLs.isEmpty || item.hasImageData {
      return nil
    }

    if let text = item.rtf?.string.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
      return text
    }

    if let text = item.html?.string.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
      return text
    }

    return nil
  }

  private static func normalize(_ text: String) -> String {
    return text
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
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
                Clipboard.shared.copy(item, removeFormatting: Defaults[.removeFormattingByDefault])
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
          QueueClipboard.shared.addFromClipboard(item)
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
      onClose: { AppState.shared.popup.reset() },
      onEndLiveResize: {
        if AppState.shared.popup.needsResize {
          AppState.shared.popup.resize(height: AppState.shared.popup.contentHeight)
        }
      }
    ) {
      ContentView()
    }
    panel.isMovableByWindowBackground = false

    queuePanel = FloatingPanel(
      contentRect: NSRect(origin: .zero, size: Defaults[.queueWindowSize]),
      identifier: (Bundle.main.bundleIdentifier ?? "org.p0deje.Maccy") + ".queue",
      statusBarButton: statusItem.button,
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
    queuePanel.isMovableByWindowBackground = false
    queuePanel.isMovableExternally = true
    queuePanel.closeOnResignKey = false // Keep open when focus is lost
    queuePanel.hidesOnDeactivate = false

    KeyboardShortcuts.onKeyDown(for: .queue) { [weak self] in
      self?.toggleQueue()
    }
    
    KeyboardShortcuts.onKeyDown(for: .queueClear) {
      QueueClipboard.shared.clear()
      NSSound.playMorseFeedback()
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

    KeyboardShortcuts.onKeyDown(for: .queueToggleSplit) {
      Defaults[.queueAutoSplitText].toggle()
      NSSound.playMorseFeedback()
    }

    KeyboardShortcuts.onKeyDown(for: .queueTogglePasteOrder) {
      Defaults[.queuePasteLifo].toggle()
      NSSound.playMorseFeedback()
    }

    KeyboardShortcuts.onKeyDown(for: .queueCycleSeparatorPreset) {
      _ = QueueSeparator.cycleCurrentPreset()
      NSSound.playMorseFeedback()
    }

    #if DEBUG
    guard !CommandLine.arguments.contains("enable-testing") else {
      return
    }
    #endif

    DispatchQueue.main.async {
      Accessibility.shared.checkAndPresentIfNeeded()
    }
  }

  @MainActor
  private func toggleQueue() {
    guard Accessibility.shared.checkAndPresentIfNeeded() else {
      return
    }

    if queuePanel.isPresented {
      queuePanel.close()
    } else {
      QueueClipboard.shared.isModeActive = true
      QueueClipboardManager.shared.startMonitoring()
      queuePanel.open(height: Defaults[.queueWindowSize].height, at: Defaults[.queuePopupPosition], makeKey: false)
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

    if Defaults[.migrations]["2026-02-23-queue-separator-presets"] != true {
      var presets = QueueSeparator.normalizedPresetSlots(Defaults[.queueSeparatorPresets])
      let legacyCustomSeparator = Defaults[.customQueueSeparator]
      if !legacyCustomSeparator.isEmpty {
        presets[0] = legacyCustomSeparator
      }

      Defaults[.queueSeparatorPresets] = presets
      Defaults[.queueActiveSeparatorPresetIndex] = QueueSeparator.normalizedPresetIndex(
        Defaults[.queueActiveSeparatorPresetIndex],
        presets: presets
      )
      Defaults[.migrations]["2026-02-23-queue-separator-presets"] = true
    }

    if Defaults[.migrations]["2026-04-17-queue-separator-preset-modes"] != true {
      let presets = QueueSeparator.normalizedPresetSlots(Defaults[.queueSeparatorPresets])
      Defaults[.queueSeparatorPresets] = presets
      Defaults[.queueSeparatorPresetModes] = QueueSeparator.migrateLegacyPresetModes(
        Defaults[.queueSeparatorPresetModes],
        presetValues: presets,
        activePresetIndex: Defaults[.queueActiveSeparatorPresetIndex],
        currentSeparator: Defaults[.queueSeparator]
      )
      _ = QueueSeparator.selectPreset(Defaults[.queueActiveSeparatorPresetIndex])
      Defaults[.migrations]["2026-04-17-queue-separator-preset-modes"] = true
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
  @Default(.queueAutoSplitText) var queueAutoSplitText
  @Default(.queueSeparator) var queueSeparator
  @Default(.queueSeparatorPresets) var queueSeparatorPresets
  @Default(.queueActiveSeparatorPresetIndex) var queueActiveSeparatorPresetIndex
  @State private var isHoveringClose = false
  @State private var draggingQueueItemID: UUID?

  private func toggleCyclePaste() {
    queueCyclePaste.toggle()
    NSSound.playMorseFeedback()
  }

  private func togglePasteOrder() {
    queuePasteLifo.toggle()
    NSSound.playMorseFeedback()
  }

  private func toggleAutoSplitText() {
    queueAutoSplitText.toggle()
    NSSound.playMorseFeedback()
  }

  private func cycleSeparatorPreset() {
    queueActiveSeparatorPresetIndex = QueueSeparator.cycleCurrentPreset()
    NSSound.playMorseFeedback()
  }

  private var separatorPresetPreview: String {
    QueueSeparator.currentPresetPreview()
  }

  var body: some View {
    ZStack {
      VStack(alignment: .leading, spacing: 0) {
        // Header
        ZStack {
          QueueWindowDragHandleView()
            .frame(maxWidth: .infinity)
            .frame(height: 22)

          Text("Queue Clipboard")
            .font(.system(size: 13, weight: .semibold))
            .frame(maxWidth: .infinity, alignment: .center)
            .allowsHitTesting(false)
            
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
              ForEach(queue.items) { queueItem in
                QueueItemView(queueItem: queueItem)
                  .onDrag {
                    draggingQueueItemID = queueItem.id
                    return NSItemProvider(object: queueItem.id.uuidString as NSString)
                  }
                  .onDrop(
                    of: [UTType.text],
                    delegate: QueueItemReorderDropDelegate(
                      targetItemID: queueItem.id,
                      queue: queue,
                      draggingQueueItemID: $draggingQueueItemID
                    )
                  )
              }

              Color.clear
                .frame(height: 16)
                .onDrop(
                  of: [UTType.text],
                  delegate: QueueReorderToEndDropDelegate(
                    queue: queue,
                    draggingQueueItemID: $draggingQueueItemID
                  )
                )
            }
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
            Button(action: toggleCyclePaste) {
              Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 14))
                .foregroundColor(queueCyclePaste ? .accentColor : .primary)
            }
            .buttonStyle(.plain)
            .help("Cycle Paste")

            Divider()
              .frame(height: 12)
              .background {
                GeometryReader { proxy in
                  Color.clear.preference(
                    key: QueueControlDividerMidpointsPreferenceKey.self,
                    value: [proxy.frame(in: .named("queue-control-space")).midX]
                  )
                }
              }

            Button(action: toggleAutoSplitText) {
              Image(systemName: "list.bullet.indent")
                .font(.system(size: 14))
                .foregroundColor(queueAutoSplitText ? .accentColor : .primary)
            }
            .buttonStyle(.plain)
            .help("Auto-Split Queue Items")

            Divider()
              .frame(height: 12)
              .background {
                GeometryReader { proxy in
                  Color.clear.preference(
                    key: QueueControlDividerMidpointsPreferenceKey.self,
                    value: [proxy.frame(in: .named("queue-control-space")).midX]
                  )
                }
              }

            Button(action: togglePasteOrder) {
              Text(queuePasteLifo ? "LIFO" : "FIFO")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .frame(width: 30) // Fixed width to prevent jitter
            .help("Toggle Paste Order")

            Divider()
              .frame(height: 12)
              .background {
                GeometryReader { proxy in
                  Color.clear.preference(
                    key: QueueControlDividerMidpointsPreferenceKey.self,
                    value: [proxy.frame(in: .named("queue-control-space")).midX]
                  )
                }
              }

            Button(action: cycleSeparatorPreset) {
              Text(separatorPresetPreview)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .frame(width: 42)
            .help("Cycle Separator Preset")
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .coordinateSpace(name: "queue-control-space")
          .background(.regularMaterial, in: Capsule())
          .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
          .overlayPreferenceValue(QueueControlDividerMidpointsPreferenceKey.self) { points in
            GeometryReader { proxy in
              let sortedPoints = points.sorted()
              let firstDividerX = sortedPoints.first ?? proxy.size.width / 4
              let secondDividerX = sortedPoints.count > 1 ? sortedPoints[1] : proxy.size.width / 2
              let thirdDividerX = sortedPoints.count > 2 ? sortedPoints[2] : proxy.size.width * 3 / 4

              HStack(spacing: 0) {
                Color.clear
                  .frame(width: max(0, firstDividerX))
                  .contentShape(Rectangle())
                  .onTapGesture(perform: toggleCyclePaste)

                Color.clear
                  .frame(width: max(0, secondDividerX - firstDividerX))
                  .contentShape(Rectangle())
                  .onTapGesture(perform: toggleAutoSplitText)

                Color.clear
                  .frame(width: max(0, thirdDividerX - secondDividerX))
                  .contentShape(Rectangle())
                  .onTapGesture(perform: togglePasteOrder)

                Color.clear
                  .frame(maxWidth: .infinity)
                  .contentShape(Rectangle())
                  .onTapGesture(perform: cycleSeparatorPreset)
              }
            }
          }
          .overlay(
            Capsule()
              .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
          )
          
          Spacer()
          
          // Right Button: Clear
          Button(action: {
            queue.clear()
            NSSound.playMorseFeedback()
          }) {
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

private struct QueueWindowDragHandleView: NSViewRepresentable {
  func makeNSView(context: Context) -> QueueWindowDragHandleNSView {
    QueueWindowDragHandleNSView()
  }

  func updateNSView(_ nsView: QueueWindowDragHandleNSView, context: Context) {}
}

private final class QueueWindowDragHandleNSView: NSView {
  override func mouseDown(with event: NSEvent) {
    window?.performDrag(with: event)
  }
}

private struct QueueItemReorderDropDelegate: DropDelegate {
  let targetItemID: UUID
  let queue: QueueClipboard
  @Binding var draggingQueueItemID: UUID?

  func validateDrop(info: DropInfo) -> Bool {
    draggingQueueItemID != nil
  }

  func dropEntered(info: DropInfo) {
    guard let draggingQueueItemID else {
      return
    }

    queue.move(itemWithID: draggingQueueItemID, beforeItemWithID: targetItemID)
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    DropProposal(operation: .move)
  }

  func performDrop(info: DropInfo) -> Bool {
    draggingQueueItemID = nil
    return true
  }
}

private struct QueueReorderToEndDropDelegate: DropDelegate {
  let queue: QueueClipboard
  @Binding var draggingQueueItemID: UUID?

  func validateDrop(info: DropInfo) -> Bool {
    draggingQueueItemID != nil
  }

  func dropEntered(info: DropInfo) {
    guard let draggingQueueItemID else {
      return
    }

    queue.moveToEnd(itemWithID: draggingQueueItemID)
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    DropProposal(operation: .move)
  }

  func performDrop(info: DropInfo) -> Bool {
    draggingQueueItemID = nil
    return true
  }
}

struct QueueItemView: View {
  let queueItem: QueueClipboard.QueueItem
  @State private var isHovering = false
  @State private var thumbnailImage: NSImage?

  private static let thumbnailSize = NSSize(width: 80, height: 45)

  var body: some View {
    ZStack(alignment: .trailing) {
      HStack(alignment: .top, spacing: 10) {
        VStack(alignment: .leading, spacing: 2) {
          if let image = thumbnailImage {
            Image(nsImage: image)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: Self.thumbnailSize.width, height: Self.thumbnailSize.height)
              .cornerRadius(4)
          } else if queueItem.item.hasImageData {
            ProgressView()
              .frame(width: Self.thumbnailSize.width, height: Self.thumbnailSize.height)
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
      .onTapGesture {
        // 1. Ensure focus goes back to the previous app
        NSApp.deactivate()
        
        // 2. Prepare for internal paste bypass
        QueueClipboardManager.shared.isInternalPaste = true
        
        // 3. Copy the item
        Clipboard.shared.copy(queueItem.item, removeFormatting: Defaults[.removeFormattingByDefault])
        
        // 4. Paste with a slight delay to allow focus switch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          Clipboard.shared.paste()
        }
      }
      
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
    .task(id: queueItem.id) {
      await generateThumbnailIfNeeded()
    }
    .onDisappear {
      thumbnailImage?.recache()
      thumbnailImage = nil
    }
  }

  @MainActor
  private func generateThumbnailIfNeeded() async {
    guard thumbnailImage == nil, queueItem.item.hasImageData else {
      return
    }

    let item = queueItem.item
    let thumbnailImage: NSImage?
    if let imageSourceURL = item.imageSourceURL {
      thumbnailImage = await Task.detached(priority: .utility) {
        autoreleasepool {
          NSImage.downsampled(contentsOf: imageSourceURL, to: Self.thumbnailSize)
        }
      }.value
    } else if let imageData = item.imageData {
      thumbnailImage = await Task.detached(priority: .utility) {
        autoreleasepool {
          NSImage.downsampled(data: imageData, to: Self.thumbnailSize)
        }
      }.value
    } else {
      thumbnailImage = nil
    }

    guard !Task.isCancelled else {
      return
    }

    self.thumbnailImage = thumbnailImage
  }
}
