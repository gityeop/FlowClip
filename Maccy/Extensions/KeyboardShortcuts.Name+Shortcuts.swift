import KeyboardShortcuts

extension KeyboardShortcuts.Name {
  static let popup = Self("popup", default: Shortcut(.c, modifiers: [.command, .shift]))
  static let pin = Self("pin", default: Shortcut(.p, modifiers: [.option]))
  static let delete = Self("delete", default: Shortcut(.delete, modifiers: [.option]))
  static let queue = Self("queue", default: Shortcut(.v, modifiers: [.option, .shift]))
  static let queueClear = Self("queueClear", default: Shortcut(.delete, modifiers: [.option, .shift]))
  static let queuePasteAll = Self("queuePasteAll")
}
