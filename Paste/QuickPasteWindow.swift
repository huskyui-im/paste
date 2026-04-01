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
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        var origin = position

        if origin.x + 320 > screenFrame.maxX {
            origin.x = screenFrame.maxX - 320
        }
        if origin.x < screenFrame.minX {
            origin.x = screenFrame.minX
        }
        origin.y -= 400
        if origin.y < screenFrame.minY {
            origin.y = position.y + 20
        }

        self.setFrameOrigin(origin)
        self.makeKeyAndOrderFront(nil)

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
        if item.isImage, let data = item.imageData {
            clipboardService.copyImageToClipboard(data)
        } else {
            clipboardService.copyToClipboard(item.content)
        }

        dismiss()

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
                    let screenHeight = NSScreen.main?.frame.height ?? 0
                    return NSPoint(x: rect.origin.x, y: screenHeight - rect.origin.y - rect.size.height)
                }
            }
        }

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
