# Quick Paste Popup - Design Spec

## Overview

A global hotkey-triggered floating popup that shows clipboard history near the text input caret, allowing users to quickly select and paste clipboard items in any application. This is a **new feature** that does not modify existing functionality.

## Trigger

- **Global Hotkey**: `Cmd+Shift+V`
- Registered via Carbon Event Manager in `AppDelegate`, same pattern as existing `Cmd+Shift+P` and `Cmd+Shift+S`

## Window Positioning

1. **Primary**: Follow the text input caret position in the active application
   - Use macOS Accessibility API (`AXUIElementCopyAttributeValue` with `kAXBoundsForRangeParameterizedAttribute` or `kAXPositionAttribute`) to get the caret position of the focused text element
   - Requires Accessibility permission (`AXIsProcessTrustedWithOptions`)
2. **Fallback**: Center of the current screen (when caret position is unavailable)

## Window: QuickPasteWindow

**New file**: `QuickPasteWindow.swift`

An `NSWindow` subclass with the following properties:

- **Style**: `.borderless` (no title bar)
- **Level**: `.floating` (always on top of other windows)
- **Backing**: `.buffered`
- **Background**: Transparent window background; visual effect provided by SwiftUI content
- **Size**: ~300px wide, height adapts to content (max ~10 items)
- **Appearance**: Rounded corners, shadow, vibrancy/blur background (NSVisualEffectView or SwiftUI `.background(.ultraThinMaterial)`)
- **Behavior**:
  - Does not appear in Dock or app switcher
  - Does not become key window in a way that steals focus from the target app (use `canBecomeKey = true` only for keyboard event handling, resign immediately after selection)
  - Closes on: item selection, Esc key, click outside window, `Cmd+Shift+V` again (toggle)

**Key Methods**:
- `showAtPosition(_ point: NSPoint)` — position and show the window
- `dismiss()` — hide/close the window

## View: QuickPasteView

**New file**: `QuickPasteView.swift`

A SwiftUI view embedded in the window via `NSHostingController`.

### Content

- Displays items from `ClipboardService.clipboardHistory` (shared instance, read-only)
- Each row shows:
  - **Text items**: First line of content, truncated to ~50 characters
  - **Image items**: Small thumbnail (~24x24) + "Image" label
  - **Index number** (1-9) shown on the left for keyboard shortcut reference
- Maximum 10 items displayed
- Visual highlight on the currently selected item

### Interaction

| Input | Action |
|-------|--------|
| `Up Arrow` / `Down Arrow` | Move selection up/down |
| `Enter` | Confirm selection, paste |
| `1`-`9` | Select item at index directly, paste |
| `Esc` | Close popup without action |
| Mouse hover | Highlight item |
| Mouse click | Confirm selection, paste |

### Selection & Paste Flow

1. User selects an item (keyboard or mouse)
2. Write the selected content to `NSPasteboard.general` (via existing `ClipboardService.copyToClipboard` / `copyImageToClipboard`)
3. Dismiss the popup window
4. Wait a brief delay (~50ms) for window dismissal and focus return
5. Simulate `Cmd+V` keystroke via `CGEvent`:
   ```
   CGEvent(keyboardEventSource:, virtualKey: 0x09 /*V*/, keyDown: true)
   event.flags = .maskCommand
   event.post(tap: .cghidEventTap)
   ```

## Changes to Existing Files

### AppDelegate.swift

Minimal additions only:

1. **New property**: `var quickPasteWindow: QuickPasteWindow?`
2. **Register hotkey**: Add `Cmd+Shift+V` (keyCode 9 for V) in `registerHotKey()`, with a new `EventHotKeyID` (id = 3)
3. **Handle hotkey**: In the event handler, call a new method `toggleQuickPaste()`
4. **`toggleQuickPaste()` method**:
   - If window is visible, dismiss it
   - Otherwise, get caret position via Accessibility API, show window

No changes to existing popover, screenshot, or clipboard logic.

## Accessibility Permission

- Use `AXIsProcessTrustedWithOptions` to check/request accessibility permission
- If not granted, fall back to screen center positioning (do not block the feature)
- The app already runs without sandbox (`com.apple.security.app-sandbox = false`), so no entitlement issues

## Caret Position Detection

Helper function to get the focused text element's caret position:

1. `NSWorkspace.shared.frontmostApplication` to get the active app's PID
2. `AXUIElementCreateApplication(pid)` to create AX element
3. Get `kAXFocusedUIElementAttribute` to find the focused element
4. Get `kAXSelectedTextRangeAttribute` for the caret range
5. Use `kAXBoundsForRangeParameterizedAttribute` to get the screen rect of the caret
6. Convert coordinates (AX uses top-left origin) to NSScreen coordinates (bottom-left origin)

If any step fails, return `nil` and fall back to screen center.

## File Summary

| File | Action | Description |
|------|--------|-------------|
| `QuickPasteWindow.swift` | **New** | NSWindow subclass for the floating popup |
| `QuickPasteView.swift` | **New** | SwiftUI view for the clipboard list UI |
| `AppDelegate.swift` | **Modify** | Register hotkey + toggle logic (additive only) |

## Out of Scope

- Search/filtering within the quick paste popup (keep it minimal)
- Customizable hotkey
- Drag and drop from popup
- Any changes to the existing main popover (ContentView) or toolbar
