# FlowClip
 
[![Downloads](https://img.shields.io/github/downloads/gityeop/FlowClip/total.svg)](https://github.com/gityeop/FlowClip/releases/latest)
[![Version](https://img.shields.io/github/v/release/gityeop/FlowClip)](https://github.com/gityeop/FlowClip/releases/latest)
 
<img align="left" width="128" height="128" src="docs/icon_readme.png" alt="FlowClip Icon">

**FlowClip** allows you to keep the existing powerful features of Maccy while leveraging the new **Queue Clipboard** capability. With FlowClip, you can easily perform batch operations.

FlowClip is a fork of [Maccy](https://maccy.app), keeping it lightweight, fast, and open-source.
<br clear="left"/>

## ✨ Key Features

### 🚀 Queue Clipboard (New!)
Copy multiple items one after another and paste them sequentially or all at once.

- **Batch Copy**: Copy text or images multiple times to build a queue.
- **Sequential Paste**: Paste items in the order they were queued (FIFO).
- **Custom Separators**: When pasting all items, choose to separate them with a space, new line, comma, or any custom character.
- **Visual Queue**: View and manage your queued items in a dedicated floating window.

> [!IMPORTANT]
> **To use Queue Clipboard:** You must grant **Accessibility permissions** to FlowClip in System Settings. Please **restart the app** after granting permission.

### Core Features (inherited from Maccy)
- Lightweight & Fast
- Keyboard-first navigation
- Secure & Private
- Native UI (macOS standard)

## Install

### GitHub Releases
Download the latest version from the [Releases page](https://github.com/gityeop/FlowClip/releases/latest).

### Homebrew
*(Instructions for Homebrew installation will be available after registration)*
```sh
# Example command (Coming Soon)
brew install flowclip
```

## Usage

1. **General**: <kbd>SHIFT (⇧)</kbd> + <kbd>COMMAND (⌘)</kbd> + <kbd>C</kbd> to popup FlowClip.
2. **Queue Mode**: 
   - Toggle Queue Window: <kbd>OPTION (⌥)</kbd> + <kbd>SHIFT (⇧)</kbd> + <kbd>V</kbd>
   - Copy items normally using <kbd>COMMAND (⌘)</kbd> + <kbd>C</kbd> while Queue Mode is active.
   - Use the Queue Window to manage or clear items.
   
3. **Select & Paste**:
   - Type to search.
   - <kbd>ENTER</kbd> to copy.
   - <kbd>OPTION (⌥)</kbd> + <kbd>ENTER</kbd> to paste.

For advanced usage and configuration, please refer to the application preferences.

## License

MIT License.

Based on [Maccy](https://github.com/p0deje/Maccy) by Alex Rodionov.
Copyright (c) 2026 Sang Yeop Lim (FlowClip)
Copyright (c) 2018 Alex Rodionov (Maccy)
