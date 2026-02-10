import SwiftUI
import Defaults
import KeyboardShortcuts
import LaunchAtLogin
import Settings

struct GeneralSettingsPane: View {
  private let notificationsURL = URL(
    string: "x-apple.systempreferences:com.apple.preference.notifications?id=\(Bundle.main.bundleIdentifier ?? "")"
  )

  @Default(.searchMode) private var searchMode
  @Default(.queueSeparator) private var queueSeparator
  @Default(.customQueueSeparator) private var customQueueSeparator

  @State private var copyModifier = HistoryItemAction.copy.modifierFlags.description
  @State private var pasteModifier = HistoryItemAction.paste.modifierFlags.description
  @State private var pasteWithoutFormatting = HistoryItemAction.pasteWithoutFormatting.modifierFlags.description

  @State private var showCustomHelp = false
  @State private var updater = SoftwareUpdater()

  var body: some View {
    Settings.Container(contentWidth: 520) {
      Settings.Section(title: "", bottomDivider: true) {
        LaunchAtLogin.Toggle {
          Text("LaunchAtLogin", tableName: "GeneralSettings")
        }
        Toggle(isOn: $updater.automaticallyChecksForUpdates) {
          Text("CheckForUpdates", tableName: "GeneralSettings")
        }
        Button(
          action: { updater.checkForUpdates() },
          label: { Text("CheckNow", tableName: "GeneralSettings") }
        )
      }

      Settings.Section(label: { Text("Open", tableName: "GeneralSettings") }) {
        KeyboardShortcuts.Recorder(for: .popup, onChange: { newShortcut in
          if newShortcut == nil {
            // No shortcut is recorded. Remove keys monitor
            AppState.shared.popup.deinitEventsMonitor()
          } else {
            // User is using shortcut. Ensure keys monitor is initialized
            AppState.shared.popup.initEventsMonitor()
          }
        })
          .help(Text("OpenTooltip", tableName: "GeneralSettings"))
      }

      Settings.Section(label: { Text("Pin", tableName: "GeneralSettings") }) {
        KeyboardShortcuts.Recorder(for: .pin)
          .help(Text("PinTooltip", tableName: "GeneralSettings"))
      }
      Settings.Section(
        label: { Text("Delete", tableName: "GeneralSettings") }
      ) {
        KeyboardShortcuts.Recorder(for: .delete)
          .help(Text("DeleteTooltip", tableName: "GeneralSettings"))
      }

      Settings.Section(
        label: { Text("Open Queue:", tableName: "GeneralSettings") }
      ) {
        KeyboardShortcuts.Recorder(for: .queue)
      }

      Settings.Section(
        label: { Text("Clear Queue:", tableName: "GeneralSettings") }
      ) {
        KeyboardShortcuts.Recorder(for: .queueClear)
      }
      
      Settings.Section(
        label: { Text("Paste All:", tableName: "GeneralSettings") }
      ) {
        KeyboardShortcuts.Recorder(for: .queuePasteAll)
      }

      Settings.Section(
        label: { Text("ToggleQueueAutoSplit", tableName: "GeneralSettings") }
      ) {
        KeyboardShortcuts.Recorder(for: .queueToggleSplit)
      }

      Settings.Section(
        bottomDivider: true,
        label: { Text("ToggleQueueOrder", tableName: "GeneralSettings") }
      ) {
        KeyboardShortcuts.Recorder(for: .queueTogglePasteOrder)
      }

      Settings.Section(
        bottomDivider: true,
        label: { Text("Search", tableName: "GeneralSettings") }
      ) {
        Picker("", selection: $searchMode) {
          ForEach(Search.Mode.allCases) { mode in
            Text(mode.description)
          }
        }
        .labelsHidden()
        .frame(width: 180, alignment: .leading)
      }

      Settings.Section(
        bottomDivider: true,
        label: { Text("Behavior", tableName: "GeneralSettings") }
      ) {
        Defaults.Toggle(key: .pasteByDefault) {
          Text("PasteAutomatically", tableName: "GeneralSettings")
        }
        .onChange(refreshModifiers)
        .fixedSize(horizontal: false, vertical: true)

        Defaults.Toggle(key: .removeFormattingByDefault) {
          Text("PasteWithoutFormatting", tableName: "GeneralSettings")
        }
        .onChange(refreshModifiers)
        .fixedSize(horizontal: false, vertical: true)

        Defaults.Toggle(key: .queueAutoSplitText) {
          Text("QueueAutoSplitCopiedText", tableName: "GeneralSettings")
        }
        .fixedSize(horizontal: false, vertical: true)

        Text(String(
          format: NSLocalizedString("Modifiers", tableName: "GeneralSettings", comment: ""),
          copyModifier, pasteModifier, pasteWithoutFormatting
        ))
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .controlSize(.small)

        VStack(alignment: .leading, spacing: 6) {
          Text("QueuePasteSeparator", tableName: "GeneralSettings")
          Picker("", selection: $queueSeparator) {
            ForEach(QueueSeparator.allCases) { separator in
              Text(separator.description)
            }
          }
          .labelsHidden()
          .frame(width: 180, alignment: .leading)

          if queueSeparator == .custom {
            HStack(spacing: 6) {
              TextField("", text: $customQueueSeparator)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
                .padding(.leading, 4)
              Button(action: { showCustomHelp.toggle() }) {
                Image(systemName: "questionmark.circle")
                  .font(.body)
                  .foregroundColor(.secondary)
              }
              .buttonStyle(.borderless)
              .popover(isPresented: $showCustomHelp) {
                Text(NSLocalizedString("CustomSeparatorTooltip", tableName: "GeneralSettings", comment: ""))
                  .padding()
              }
            }
            .frame(width: 220, alignment: .leading)
          }
        }
        .frame(width: 220, alignment: .leading)
      }


      Settings.Section(title: "") {
        if let notificationsURL = notificationsURL {
          Link(destination: notificationsURL, label: {
            Text("NotificationsAndSounds", tableName: "GeneralSettings")
          })
        }
      }
    }
  }

  private func refreshModifiers(_ sender: Sendable) {
    copyModifier = HistoryItemAction.copy.modifierFlags.description
    pasteModifier = HistoryItemAction.paste.modifierFlags.description
    pasteWithoutFormatting = HistoryItemAction.pasteWithoutFormatting.modifierFlags.description
  }
}

#Preview {
  GeneralSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}
