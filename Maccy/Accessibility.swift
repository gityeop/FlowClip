import AppKit
import ApplicationServices
import Observation
import SwiftUI

@MainActor
@Observable
final class Accessibility {
  static let shared = Accessibility()

  private static let settingsURL = URL(
    string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
  )!

  private(set) var isAllowed: Bool

  @ObservationIgnored
  private var permissionWindowController: AccessibilityPermissionWindowController?

  private init() {
    isAllowed = Self.currentPermission
  }

  func refresh() {
    isAllowed = Self.currentPermission
  }

  func monitor() async {
    while !Task.isCancelled {
      refresh()

      do {
        try await Task.sleep(for: .milliseconds(500))
      } catch is CancellationError {
        return
      } catch {
        fatalError("Failed to monitor accessibility permission: \(error)")
      }
    }
  }

  @discardableResult
  func checkAndPresentIfNeeded() -> Bool {
    refresh()
    guard !isAllowed else {
      return true
    }

    presentPermissionWindow()
    return false
  }

  func openSystemSettings() {
    refresh()
    Task {
      do {
        _ = try await NSWorkspace.shared.open(Self.settingsURL, configuration: .init())
      } catch {
        NSAlert(error: error).runModal()
      }
    }
  }

  func closePermissionWindow() {
    permissionWindowController?.close()
  }

  private static var currentPermission: Bool {
    AXIsProcessTrustedWithOptions(nil)
  }

  private func presentPermissionWindow() {
    if let permissionWindowController {
      permissionWindowController.show()
      return
    }

    let controller = AccessibilityPermissionWindowController(accessibility: self)
    controller.onClose = { [weak self] in
      self?.permissionWindowController = nil
    }
    permissionWindowController = controller
    controller.show()
  }
}

@MainActor
struct AccessibilityStatusView: View {
  let accessibility: Accessibility

  var body: some View {
    if accessibility.isAllowed {
      Label("AccessibilityPermissionGranted", systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)
    } else {
      Label("AccessibilityPermissionMissing", systemImage: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
    }
  }
}

@MainActor
private final class AccessibilityPermissionWindowController: NSWindowController, NSWindowDelegate {
  var onClose: (() -> Void)?

  init(accessibility: Accessibility) {
    let panel = NSPanel(
      contentRect: NSRect(origin: .zero, size: NSSize(width: 420, height: 240)),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    panel.title = NSLocalizedString("AccessibilityPermissionRequired", comment: "")
    panel.animationBehavior = .utilityWindow
    panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
    panel.hidesOnDeactivate = false
    panel.isFloatingPanel = true
    panel.isMovableByWindowBackground = true
    panel.isReleasedWhenClosed = false
    panel.level = .floating

    super.init(window: panel)

    panel.delegate = self
    panel.contentViewController = NSHostingController(
      rootView: AccessibilityPermissionView(
        accessibility: accessibility,
        onClose: { accessibility.closePermissionWindow() }
      )
    )
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  func show() {
    if window?.isVisible != true {
      window?.center()
    }

    NSApp.activate()
    showWindow(nil)
    window?.orderFrontRegardless()
  }

  func windowWillClose(_ notification: Notification) {
    onClose?()
  }
}

@MainActor
private struct AccessibilityPermissionView: View {
  let accessibility: Accessibility
  let onClose: () -> Void

  private var titleKey: LocalizedStringKey {
    accessibility.isAllowed ? "AccessibilityPermissionGranted" : "AccessibilityPermissionRequired"
  }

  private var messageKey: LocalizedStringKey {
    accessibility.isAllowed
      ? "AccessibilityPermissionGrantedMessage"
      : "AccessibilityPermissionRequiredMessage"
  }

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: accessibility.isAllowed ? "checkmark.shield.fill" : "hand.raised.fill")
        .font(.system(size: 36))
        .foregroundStyle(accessibility.isAllowed ? Color.green : Color.orange)

      Text(titleKey)
        .font(.title2.weight(.semibold))

      Text(messageKey)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)

      AccessibilityStatusView(accessibility: accessibility)
        .font(.headline)

      if !accessibility.isAllowed {
        HStack {
          Spacer()
          Button("Cancel", action: onClose)
            .keyboardShortcut(.cancelAction)
          Button("OpenSystemSettings", action: accessibility.openSystemSettings)
            .keyboardShortcut(.defaultAction)
        }
      }
    }
    .padding(24)
    .frame(width: 420, height: 240)
    .task {
      await accessibility.monitor()
    }
    .task(id: accessibility.isAllowed) {
      guard accessibility.isAllowed else {
        return
      }

      do {
        try await Task.sleep(for: .seconds(1))
      } catch is CancellationError {
        return
      } catch {
        fatalError("Failed while waiting to close the accessibility permission window: \(error)")
      }

      guard accessibility.isAllowed, !Task.isCancelled else {
        return
      }
      onClose()
    }
  }
}
