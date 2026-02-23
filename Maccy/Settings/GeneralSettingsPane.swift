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
  @Default(.queueSeparatorPresets) private var queueSeparatorPresets
  @Default(.queueActiveSeparatorPresetIndex) private var queueActiveSeparatorPresetIndex

  @State private var copyModifier = HistoryItemAction.copy.modifierFlags.description
  @State private var pasteModifier = HistoryItemAction.paste.modifierFlags.description
  @State private var pasteWithoutFormatting = HistoryItemAction.pasteWithoutFormatting.modifierFlags.description

  @State private var showCustomHelp = false
  @State private var presetEditorIndex = 0
  @State private var presetEditorValue = ""
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
            VStack(alignment: .leading, spacing: 8) {
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

                Button(action: savePresetEditorValue) {
                  Text(String(
                    format: NSLocalizedString("QueueSeparatorSaveToPreset", tableName: "GeneralSettings", comment: ""),
                    presetEditorIndex + 1
                  ))
                }
                .buttonStyle(.borderless)
              }

              HStack(spacing: 8) {
                Button(action: useSelectedPreset) {
                  Text(String(
                    format: NSLocalizedString("QueueSeparatorUsePreset", tableName: "GeneralSettings", comment: ""),
                    presetEditorIndex + 1
                  ))
                }
                .buttonStyle(.borderless)

                Button(action: deleteSelectedPreset) {
                  Text("QueueSeparatorDeletePreset", tableName: "GeneralSettings")
                }
                .buttonStyle(.borderless)

                Text(String(
                  format: NSLocalizedString("QueueSeparatorCurrentPreset", tableName: "GeneralSettings", comment: ""),
                  QueueSeparator.normalizedPresetIndex(queueActiveSeparatorPresetIndex) + 1
                ))
                .foregroundStyle(.gray)
                .controlSize(.small)
              }
            }
            .frame(width: 360, alignment: .leading)
            .onAppear(perform: preparePresetEditor)
            .onChange(of: presetEditorIndex) {
              loadPresetEditorValue()
            }
            .onChange(of: queueSeparatorPresets) {
              refreshPresetEditorAfterPresetChange()
            }
          }
        }
        .frame(width: 360, alignment: .leading)
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
  }

  private func refreshModifiers(_ sender: Sendable) {
    copyModifier = HistoryItemAction.copy.modifierFlags.description
    pasteModifier = HistoryItemAction.paste.modifierFlags.description
    pasteWithoutFormatting = HistoryItemAction.pasteWithoutFormatting.modifierFlags.description
  }

  private func preparePresetEditor() {
    normalizePresetStorage()
    presetEditorIndex = QueueSeparator.normalizedPresetIndex(queueActiveSeparatorPresetIndex)
    loadPresetEditorValue()
  }

  private func normalizePresetStorage() {
    let normalizedPresets = QueueSeparator.normalizedPresetSlots(queueSeparatorPresets)
    if normalizedPresets != queueSeparatorPresets {
      queueSeparatorPresets = normalizedPresets
    }

    let normalizedIndex = QueueSeparator.normalizedPresetIndex(
      queueActiveSeparatorPresetIndex,
      presets: normalizedPresets
    )
    if normalizedIndex != queueActiveSeparatorPresetIndex {
      queueActiveSeparatorPresetIndex = normalizedIndex
    }
  }

  private func loadPresetEditorValue() {
    let presets = QueueSeparator.normalizedPresetSlots(queueSeparatorPresets)
    let normalizedIndex = QueueSeparator.normalizedPresetIndex(presetEditorIndex, presets: presets)
    if normalizedIndex != presetEditorIndex {
      presetEditorIndex = normalizedIndex
    }

    presetEditorValue = presets[normalizedIndex]
  }

  private func refreshPresetEditorAfterPresetChange() {
    normalizePresetStorage()
    loadPresetEditorValue()
  }

  private func savePresetEditorValue() {
    var presets = QueueSeparator.normalizedPresetSlots(queueSeparatorPresets)
    let index = QueueSeparator.normalizedPresetIndex(presetEditorIndex, presets: presets)

    presets[index] = presetEditorValue
    queueSeparatorPresets = presets
    queueActiveSeparatorPresetIndex = index
    queueSeparator = .custom
    customQueueSeparator = presetEditorValue
  }

  private func useSelectedPreset() {
    let presets = QueueSeparator.normalizedPresetSlots(queueSeparatorPresets)
    let index = QueueSeparator.normalizedPresetIndex(presetEditorIndex, presets: presets)

    queueActiveSeparatorPresetIndex = index
    queueSeparator = .custom
    presetEditorValue = presets[index]
    customQueueSeparator = presets[index]
  }

  private func deleteSelectedPreset() {
    var presets = QueueSeparator.normalizedPresetSlots(queueSeparatorPresets)
    let index = QueueSeparator.normalizedPresetIndex(presetEditorIndex, presets: presets)

    presets[index] = ""
    queueSeparatorPresets = presets

    if queueActiveSeparatorPresetIndex == index {
      queueActiveSeparatorPresetIndex = nextAvailablePresetIndex(in: presets, fallback: index)
    }

    customQueueSeparator = presets[QueueSeparator.normalizedPresetIndex(queueActiveSeparatorPresetIndex, presets: presets)]
    loadPresetEditorValue()
  }

  private func nextAvailablePresetIndex(in presets: [String], fallback: Int) -> Int {
    if let firstNonEmpty = presets.indices.first(where: { !presets[$0].isEmpty }) {
      return firstNonEmpty
    }

    return QueueSeparator.normalizedPresetIndex(fallback, presets: presets)
  }
}

#Preview {
  GeneralSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}
