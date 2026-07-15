import SwiftUI
import Defaults
import KeyboardShortcuts
import LaunchAtLogin
import Settings

@MainActor
struct GeneralSettingsPane: View {
  private let notificationsURL = URL(
    string: "x-apple.systempreferences:com.apple.preference.notifications?id=\(Bundle.main.bundleIdentifier ?? "")"
  )

  @Default(.searchMode) private var searchMode
  @Default(.queueSeparatorPresets) private var queueSeparatorPresets
  @Default(.queueSeparatorPresetModes) private var queueSeparatorPresetModes
  @Default(.queueActiveSeparatorPresetIndex) private var queueActiveSeparatorPresetIndex

  @State private var copyModifier = HistoryItemAction.copy.modifierFlags.description
  @State private var pasteModifier = HistoryItemAction.paste.modifierFlags.description
  @State private var pasteWithoutFormatting = HistoryItemAction.pasteWithoutFormatting.modifierFlags.description

  @State private var showCustomHelp = false
  @State private var presetEditorIndex = 0
  @State private var presetEditorValue = ""
  @State private var selectedPresetMode: QueueSeparator = .custom
  @State private var isSyncingPresetEditor = false
  @State private var updater = SoftwareUpdater()
  @State private var accessibility = Accessibility.shared

  var body: some View {
    Settings.Container(contentWidth: 520) {
      Settings.Section(
        bottomDivider: true,
        label: { Text("AccessibilityPermission") }
      ) {
        HStack(spacing: 12) {
          AccessibilityStatusView(accessibility: accessibility)
          Button("OpenSystemSettings", action: accessibility.openSystemSettings)
        }
      }

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
        label: { Text("ToggleQueueOrder", tableName: "GeneralSettings") }
      ) {
        KeyboardShortcuts.Recorder(for: .queueTogglePasteOrder)
      }

      Settings.Section(
        bottomDivider: true,
        label: { Text("CycleQueueSeparatorPreset", tableName: "GeneralSettings") }
      ) {
        KeyboardShortcuts.Recorder(for: .queueCycleSeparatorPreset)
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
      }

      Settings.Section(
        bottomDivider: true,
        label: { Text("QueuePasteSeparator", tableName: "GeneralSettings") }
      ) {
        VStack(alignment: .leading, spacing: 10) {
          HStack(spacing: 8) {
            Text("QueueSeparatorPreset", tableName: "GeneralSettings")
              .foregroundStyle(.secondary)
            Picker("", selection: $presetEditorIndex) {
              ForEach(0..<QueueSeparator.presetCount, id: \.self) { index in
                Text("\(index + 1)")
                  .tag(index)
              }
            }
            .labelsHidden()
            .frame(width: 70, alignment: .leading)
          }

          Picker("", selection: $selectedPresetMode) {
            ForEach(QueueSeparator.allCases) { separator in
              Text(separator.description)
            }
          }
          .labelsHidden()
          .frame(width: 180, alignment: .leading)

          if selectedPresetMode == .custom {
            HStack(spacing: 6) {
              TextField("", text: $presetEditorValue)
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
          }

          Button(action: deleteSelectedPreset) {
            Text("QueueSeparatorDeletePreset", tableName: "GeneralSettings")
          }
          .buttonStyle(.bordered)
          .disabled(selectedPresetMode == .custom && presetEditorValue.isEmpty)
        }
        .frame(width: 360, alignment: .leading)
        .onChange(of: presetEditorIndex) {
          guard !isSyncingPresetEditor else {
            return
          }

          activateSelectedPreset(presetEditorIndex)
        }
        .onChange(of: selectedPresetMode) {
          guard !isSyncingPresetEditor else {
            return
          }

          saveSelectedPresetMode()
        }
        .onChange(of: presetEditorValue) {
          guard !isSyncingPresetEditor else {
            return
          }

          updateSelectedPresetValue()
        }
        .onChange(of: queueActiveSeparatorPresetIndex) {
          syncPresetEditor(with: queueActiveSeparatorPresetIndex)
        }
      }


      Settings.Section(title: "") {
        if let notificationsURL = notificationsURL {
          Link(destination: notificationsURL, label: {
            Text("NotificationsAndSounds", tableName: "GeneralSettings")
          })
        }
      }
    }
    .onAppear(perform: preparePresetEditor)
    .task {
      await accessibility.monitor()
    }
  }

  private func refreshModifiers(_ sender: Sendable) {
    copyModifier = HistoryItemAction.copy.modifierFlags.description
    pasteModifier = HistoryItemAction.paste.modifierFlags.description
    pasteWithoutFormatting = HistoryItemAction.pasteWithoutFormatting.modifierFlags.description
  }

  private func preparePresetEditor() {
    normalizePresetStorage()
    syncPresetEditor(with: queueActiveSeparatorPresetIndex)
  }

  private func normalizePresetStorage() {
    let normalizedPresets = QueueSeparator.normalizedPresetSlots(queueSeparatorPresets)
    if normalizedPresets != queueSeparatorPresets {
      queueSeparatorPresets = normalizedPresets
    }

    let normalizedPresetModes = QueueSeparator.normalizedPresetModes(queueSeparatorPresetModes)
    if normalizedPresetModes != queueSeparatorPresetModes {
      queueSeparatorPresetModes = normalizedPresetModes
    }

    let normalizedIndex = QueueSeparator.normalizedPresetIndex(
      queueActiveSeparatorPresetIndex,
      presets: normalizedPresets
    )
    if normalizedIndex != queueActiveSeparatorPresetIndex {
      queueActiveSeparatorPresetIndex = normalizedIndex
    }
  }

  private func activateSelectedPreset(_ index: Int) {
    let normalizedIndex = QueueSeparator.selectPreset(index)
    if normalizedIndex != queueActiveSeparatorPresetIndex {
      queueActiveSeparatorPresetIndex = normalizedIndex
    }
    syncPresetEditor(with: normalizedIndex)
  }

  private func syncPresetEditor(with index: Int) {
    let presets = QueueSeparator.normalizedPresetSlots(queueSeparatorPresets)
    let presetModes = QueueSeparator.normalizedPresetModes(queueSeparatorPresetModes)
    let normalizedIndex = QueueSeparator.normalizedPresetIndex(index, presets: presets)
    let presetValue = presets[normalizedIndex]
    let presetMode = QueueSeparator.presetMode(at: normalizedIndex, presetModes: presetModes)

    isSyncingPresetEditor = true
    if normalizedIndex != presetEditorIndex {
      presetEditorIndex = normalizedIndex
    }
    presetEditorValue = presetValue
    selectedPresetMode = presetMode
    DispatchQueue.main.async {
      isSyncingPresetEditor = false
    }
  }

  private func saveSelectedPresetMode() {
    var presetModes = QueueSeparator.normalizedPresetModes(queueSeparatorPresetModes)
    let index = QueueSeparator.normalizedPresetIndex(presetEditorIndex, presets: presetModes)
    presetModes[index] = selectedPresetMode.rawValue
    queueSeparatorPresetModes = presetModes
    syncActiveSeparatorIfNeeded(for: index)
  }

  private func updateSelectedPresetValue() {
    var presets = QueueSeparator.normalizedPresetSlots(queueSeparatorPresets)
    let index = QueueSeparator.normalizedPresetIndex(presetEditorIndex, presets: presets)

    presets[index] = presetEditorValue
    queueSeparatorPresets = presets
    syncActiveSeparatorIfNeeded(for: index)
  }

  private func deleteSelectedPreset() {
    var presets = QueueSeparator.normalizedPresetSlots(queueSeparatorPresets)
    var presetModes = QueueSeparator.normalizedPresetModes(queueSeparatorPresetModes)
    let index = QueueSeparator.normalizedPresetIndex(presetEditorIndex, presets: presets)

    presets[index] = ""
    presetModes[index] = QueueSeparator.custom.rawValue
    queueSeparatorPresets = presets
    queueSeparatorPresetModes = presetModes
    presetEditorValue = ""
    selectedPresetMode = .custom
    syncActiveSeparatorIfNeeded(for: index)
  }

  private func syncActiveSeparatorIfNeeded(for index: Int) {
    guard QueueSeparator.normalizedPresetIndex(queueActiveSeparatorPresetIndex) == index else {
      return
    }

    _ = QueueSeparator.selectPreset(index)
  }
}

#Preview {
  GeneralSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}
