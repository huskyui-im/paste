# Quick Paste Popup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a global `Cmd+Shift+V` hotkey that shows a floating popup near the text caret, allowing users to quickly select and paste clipboard history items in any application.

**Architecture:** Two new files (`QuickPasteWindow.swift`, `QuickPasteView.swift`) plus minimal additions to `AppDelegate.swift`. The popup is an `NSWindow` subclass (borderless, floating) hosting a SwiftUI view. Caret position is obtained via the Accessibility API with a fallback to screen center.

**Tech Stack:** SwiftUI, AppKit (NSWindow), Carbon (hotkey), Accessibility API (AXUIElement), CGEvent (simulated paste)

---

### Task 1: Create QuickPasteWindow

**Files:**
- Create: `Paste/QuickPasteWindow.swift`

- [ ] **Step 1: Create QuickPasteWindow.swift with the window class and caret detection**

```swift
//
//  QuickPasteWindow.swift
//  Paste
//

import Cocoa
import SwiftUI

class QuickPasteWindow: NSWindow {

    private var hostingView: NSHostingController<QuickPasteView>?
    private var clickMonitor: Any?

    init(clipboardService: ClipboardService) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let quickPasteView = QuickPasteView(
            clipboardService: clipboardService,
            onSelect: { [weak self] item in
                self?.handleSelection(item, clipboardService: clipboardService)
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        let hosting = NSHostingController(rootView: quickPasteView)
        hosting.view.frame = self.contentRect(forFrameRect: self.frame)
        self.contentViewController = hosting
        self.hostingView = hosting
    }

    func showAtCaretOrCenter() {
        let position = Self.getCaretPosition() ?? Self.screenCenter()
        // Adjust so popup doesn't go off screen
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        var origin = position

        if origin.x + 320 > screenFrame.maxX {
            origin.x = screenFrame.maxX - 320
        }
        if origin.x < screenFrame.minX {
            origin.x = screenFrame.minX
        }
        // Place below caret; if not enough space, place above
        origin.y -= 400
        if origin.y < screenFrame.minY {
            origin.y = position.y + 20
        }

        self.setFrameOrigin(origin)
        self.makeKeyAndOrderFront(nil)

        // Monitor clicks outside the window to dismiss
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return }
            if self.isVisible {
                self.dismiss()
            }
        }
    }

    func dismiss() {
        self.orderOut(nil)
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    private func handleSelection(_ item: ClipboardItem, clipboardService: ClipboardService) {
        // 1. Copy to pasteboard
        if item.isImage, let data = item.imageData {
            clipboardService.copyImageToClipboard(data)
        } else {
            clipboardService.copyToClipboard(item.content)
        }

        // 2. Dismiss window
        dismiss()

        // 3. Simulate Cmd+V after a brief delay for focus to return
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Self.simulatePaste()
        }
    }

    // MARK: - Caret Position via Accessibility API

    static func getCaretPosition() -> NSPoint? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var focusedElement: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard focusResult == .success else { return nil }

        // Try to get caret position via selected text range bounds
        var selectedRange: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXSelectedTextRangeAttribute as CFString, &selectedRange)

        if rangeResult == .success, let range = selectedRange {
            var bounds: AnyObject?
            let boundsResult = AXUIElementCopyParameterizedAttributeValue(
                focusedElement as! AXUIElement,
                kAXBoundsForRangeParameterizedAttribute as CFString,
                range,
                &bounds
            )
            if boundsResult == .success, let boundsValue = bounds {
                var rect = CGRect.zero
                if AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect) {
                    // AX uses top-left origin; convert to NSScreen bottom-left origin
                    let screenHeight = NSScreen.main?.frame.height ?? 0
                    return NSPoint(x: rect.origin.x, y: screenHeight - rect.origin.y - rect.size.height)
                }
            }
        }

        // Fallback: get the position of the focused element itself
        var positionValue: AnyObject?
        let posResult = AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXPositionAttribute as CFString, &positionValue)
        if posResult == .success, let posVal = positionValue {
            var point = CGPoint.zero
            if AXValueGetValue(posVal as! AXValue, .cgPoint, &point) {
                let screenHeight = NSScreen.main?.frame.height ?? 0
                return NSPoint(x: point.x, y: screenHeight - point.y)
            }
        }

        return nil
    }

    static func screenCenter() -> NSPoint {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        return NSPoint(x: screen.midX - 160, y: screen.midY + 200)
    }

    // MARK: - Simulate Cmd+V

    static func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 0x09 = V
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    // Allow the window to receive key events
    override var canBecomeKey: Bool { true }
}
```

- [ ] **Step 2: Verify file compiles**

Build the project in Xcode or run:
```bash
xcodebuild -project Paste.xcodeproj -scheme Paste build 2>&1 | tail -5
```

Note: This will fail because `QuickPasteView` doesn't exist yet — that's expected. Verify only that there are no syntax errors in this file by checking the error is about the missing `QuickPasteView` type.

- [ ] **Step 3: Commit**

```bash
git add Paste/QuickPasteWindow.swift
git commit -m "feat: add QuickPasteWindow with caret detection and simulated paste"
```

---

### Task 2: Create QuickPasteView

**Files:**
- Create: `Paste/QuickPasteView.swift`

- [ ] **Step 1: Create QuickPasteView.swift with the SwiftUI list UI**

```swift
//
//  QuickPasteView.swift
//  Paste
//

import SwiftUI

struct QuickPasteView: View {
    @ObservedObject var clipboardService: ClipboardService
    let onSelect: (ClipboardItem) -> Void
    let onDismiss: () -> Void

    @State private var selectedIndex: Int = 0
    @State private var keyMonitor: Any?

    var items: [ClipboardItem] {
        Array(clipboardService.clipboardHistory.prefix(10))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "clipboard")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("Quick Paste")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("ESC to close")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 28, weight: .thin))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No clipboard history")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                QuickPasteRow(
                                    item: item,
                                    index: index + 1,
                                    isSelected: index == selectedIndex
                                )
                                .id(index)
                                .onTapGesture {
                                    onSelect(item)
                                }
                                .onHover { hovering in
                                    if hovering { selectedIndex = index }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: selectedIndex) { newIndex in
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 320)
        .frame(maxHeight: 400)
        .fixedSize(horizontal: false, vertical: true)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            selectedIndex = 0
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                let itemCount = items.count
                guard itemCount > 0 else {
                    if event.keyCode == 53 { // Esc
                        onDismiss()
                        return nil
                    }
                    return event
                }

                // Number keys 1-9 for quick select
                if !event.modifierFlags.contains(.command),
                   let chars = event.charactersIgnoringModifiers,
                   let digit = Int(chars), digit >= 1, digit <= 9 {
                    let idx = digit - 1
                    if idx < itemCount {
                        onSelect(items[idx])
                    }
                    return nil
                }

                switch event.keyCode {
                case 126: // Up
                    selectedIndex = max(0, selectedIndex - 1)
                    return nil
                case 125: // Down
                    selectedIndex = min(itemCount - 1, selectedIndex + 1)
                    return nil
                case 36: // Enter
                    if selectedIndex < itemCount {
                        onSelect(items[selectedIndex])
                    }
                    return nil
                case 53: // Esc
                    onDismiss()
                    return nil
                default:
                    return event
                }
            }
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }
    }
}

struct QuickPasteRow: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Index badge
            Text("\(index)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 18, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )

            // Content
            if item.isImage, let data = item.imageData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text("Image")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                Text(item.content.components(separatedBy: .newlines).first ?? item.content)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            Text(item.timestamp, style: .time)
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .padding(.horizontal, 4)
    }
}
```

- [ ] **Step 2: Verify both files compile together**

```bash
xcodebuild -project Paste.xcodeproj -scheme Paste build 2>&1 | tail -10
```

Expected: Build succeeds (or only unrelated warnings).

- [ ] **Step 3: Commit**

```bash
git add Paste/QuickPasteView.swift
git commit -m "feat: add QuickPasteView with keyboard navigation and mouse selection"
```

---

### Task 3: Register Hotkey and Wire Up in AppDelegate

**Files:**
- Modify: `Paste/AppDelegate.swift`

- [ ] **Step 1: Add QuickPasteWindow property and hotkey ref**

In `AppDelegate.swift`, add after the existing property declarations (line 17):

```swift
var quickPasteHotKeyRef: EventHotKeyRef?
var quickPasteWindow: QuickPasteWindow?
```

- [ ] **Step 2: Add the toggleQuickPaste method**

Add this method after the existing `startScreenshot()` method (after line 165):

```swift
func toggleQuickPaste() {
    if let window = quickPasteWindow, window.isVisible {
        quickPasteWindow?.dismiss()
    } else {
        if quickPasteWindow == nil {
            quickPasteWindow = QuickPasteWindow(clipboardService: clipboardService)
        }
        quickPasteWindow?.showAtCaretOrCenter()
    }
}
```

- [ ] **Step 3: Register Cmd+Shift+V hotkey**

In `registerHotKey()`, add after the screenshot hotkey registration (after line 154):

```swift
// Command+Shift+V: keyCode 9 (kVK_ANSI_V) — Quick Paste
let hotKeyID3 = EventHotKeyID(signature: OSType(0x50535445), id: 3)
RegisterEventHotKey(UInt32(kVK_ANSI_V), modifiers, hotKeyID3, GetApplicationEventTarget(), 0, &quickPasteHotKeyRef)
```

- [ ] **Step 4: Handle hotkey ID 3 in the event handler switch**

In the `registerHotKey()` method, inside the `switch hotKeyID.id` block (around line 131), add a new case:

```swift
case 3:
    appDelegate.toggleQuickPaste()
```

- [ ] **Step 5: Unregister hotkey on termination**

In `applicationWillTerminate`, add after the existing unregister calls (after line 173):

```swift
if let quickPasteHotKeyRef = quickPasteHotKeyRef {
    UnregisterEventHotKey(quickPasteHotKeyRef)
}
```

- [ ] **Step 6: Build and verify**

```bash
xcodebuild -project Paste.xcodeproj -scheme Paste build 2>&1 | tail -10
```

Expected: Build succeeds.

- [ ] **Step 7: Commit**

```bash
git add Paste/AppDelegate.swift
git commit -m "feat: register Cmd+Shift+V hotkey for quick paste popup"
```

---

### Task 4: Manual Testing & Polish

- [ ] **Step 1: Run the app and test the full flow**

1. Launch the app from Xcode
2. Copy some text in any application (e.g., Safari, TextEdit)
3. Place cursor in a text input field
4. Press `Cmd+Shift+V` — verify popup appears near the caret
5. Use `Up/Down` arrow keys to navigate — verify highlight moves
6. Press `Enter` — verify text is pasted into the input field
7. Repeat and test number keys `1-9` for direct selection
8. Repeat and test mouse click selection
9. Press `Cmd+Shift+V` then `Esc` — verify popup closes without pasting
10. Press `Cmd+Shift+V` then click outside — verify popup closes
11. Test with no clipboard history — verify empty state shows
12. Verify `Cmd+Shift+P` (main popover) and `Cmd+Shift+S` (screenshot) still work unchanged

- [ ] **Step 2: Test accessibility fallback**

1. If accessibility permission is not granted, verify popup appears at screen center
2. Grant accessibility permission in System Settings > Privacy & Security > Accessibility
3. Verify popup now appears near the text caret

- [ ] **Step 3: Commit final state**

```bash
git add -A
git commit -m "feat: quick paste popup - complete implementation"
```
