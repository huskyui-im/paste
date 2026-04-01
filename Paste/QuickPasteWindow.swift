//
//  QuickPasteWindow.swift
//  Paste
//

import Cocoa
import SwiftUI

class QuickPasteWindow: NSPanel {

    private var hostingView: NSHostingController<QuickPasteView>?
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?

    init(clipboardService: ClipboardService) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .popUpMenu
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false
        self.becomesKeyOnlyIfNeeded = true

        let quickPasteView = QuickPasteView(
            items: Array(clipboardService.clipboardHistory.prefix(10)),
            onSelect: { [weak self] item in
                self?.handleSelection(item, clipboardService: clipboardService)
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        let hosting = NSHostingController(rootView: quickPasteView)
        hosting.sizingOptions = [.preferredContentSize]
        self.contentViewController = hosting
        self.hostingView = hosting
    }

    func showAtCaretOrCenter() {
        // Save the frontmost app BEFORE we do anything
        previousApp = NSWorkspace.shared.frontmostApplication

        // Get caret position while the original app still has focus
        let position = Self.getCaretPosition() ?? Self.screenCenter()

        // Calculate window size
        if let hostingView = self.contentViewController as? NSHostingController<QuickPasteView> {
            let fittingSize = hostingView.sizeThatFits(in: NSSize(width: 320, height: 400))
            self.setContentSize(fittingSize)
        }

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let windowSize = self.frame.size
        var origin = position

        if origin.x + windowSize.width > screenFrame.maxX {
            origin.x = screenFrame.maxX - windowSize.width
        }
        if origin.x < screenFrame.minX {
            origin.x = screenFrame.minX
        }
        // Place below caret
        origin.y -= windowSize.height
        if origin.y < screenFrame.minY {
            origin.y = position.y + 20
        }

        self.setFrameOrigin(origin)
        self.orderFrontRegardless()

        // Immediately restore focus to the original app
        // The panel stays visible due to .popUpMenu level + hidesOnDeactivate = false
        if let app = previousApp {
            app.activate()
        }

        // Monitor clicks outside to dismiss
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isVisible else { return }
            let windowFrame = self.frame
            let clickLocation = event.locationInWindow
            // If the click is outside our window, dismiss
            if !NSPointInRect(NSEvent.mouseLocation, windowFrame) {
                self.dismiss()
            }
        }

        // Use global key monitor since we don't steal focus
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isVisible else { return }
            self.handleKeyEvent(event)
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard let hostingView = self.hostingView else { return }
        // Forward the key event to the SwiftUI view via notification
        NotificationCenter.default.post(
            name: .quickPasteKeyEvent,
            object: nil,
            userInfo: ["keyCode": event.keyCode, "characters": event.charactersIgnoringModifiers ?? "", "modifierFlags": event.modifierFlags.rawValue]
        )
    }

    func dismiss() {
        self.orderOut(nil)
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
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

        // 3. Re-activate the original app, then simulate paste
        if let app = previousApp {
            app.activate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
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

        // Try to get caret rect via selected text range
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

        // Fallback: position of the focused element itself
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

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    override var canBecomeKey: Bool { true }
}

extension Notification.Name {
    static let quickPasteKeyEvent = Notification.Name("quickPasteKeyEvent")
}
