//
//  QuickPasteWindow.swift
//  Paste
//

import Cocoa
import SwiftUI

class QuickPasteWindow: NSPanel {
    private static let axEditableAttribute = "AXEditable"

    /// Set to `true` to print Accessibility lookup diagnostics to Console.
    static var debugAnchorLogging = false

    private enum AnchorSource: String {
        case caret
        case caretViaChild
        case caretViaParent
        case inputFrame
        case windowComposerFallback
        case screenCenter
    }

    private struct AnchorRect {
        let rect: CGRect
        let prefersLeadingEdge: Bool
        let source: AnchorSource
    }

    private static let browserBundleIDs: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "org.chromium.Chromium",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi",
        "org.mozilla.firefox",
        "org.mozilla.nightly",
        "com.apple.Safari",
    ]

    private static let textInputRoles: Set<String> = [
        kAXTextFieldRole as String,
        kAXTextAreaRole as String,
        kAXSearchFieldSubrole as String,
        kAXComboBoxRole as String
    ]

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
            clipboardService: clipboardService,
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

    /// Returns `true` when Accessibility is authorized (or the user just approved the prompt).
    static func ensureAccessibilityPermission() -> Bool {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            // Show the system prompt that guides the user to grant permission
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
        return trusted
    }

    func showAtCaretOrCenter() {
        // Check Accessibility permission — prompt if missing
        if !Self.ensureAccessibilityPermission() {
            Self.debugLog("⚠️ Accessibility permission NOT granted — caret tracking unavailable, falling back to screen center")
        }

        // Save the frontmost app BEFORE we do anything
        previousApp = NSWorkspace.shared.frontmostApplication

        // Calculate window size
        if let hostingView = self.contentViewController as? NSHostingController<QuickPasteView> {
            let fittingSize = hostingView.sizeThatFits(in: NSSize(width: 320, height: 400))
            self.setContentSize(fittingSize)
        }

        let windowSize = self.frame.size
        let anchor = Self.getAnchorRect()
        let screenFrame = anchor.flatMap { Self.screen(containing: $0.rect) }?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        var origin = Self.origin(for: anchor, windowSize: windowSize, screenFrame: screenFrame)

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

    // MARK: - Debug Logging

    private static func debugLog(_ message: @autoclosure () -> String) {
//        guard debugAnchorLogging else { return }
//        NSLog("[QuickPaste] %@", message())
    }

    private static func dumpElementInfo(_ label: String, _ element: AXUIElement) {
//        guard debugAnchorLogging else { return }
//        let role = stringValue(for: kAXRoleAttribute, in: element) ?? "nil"
//        let subrole = stringValue(for: kAXSubroleAttribute, in: element) ?? "nil"
//        let editable = boolValue(for: axEditableAttribute, in: element)
//        let hasRange = hasAttribute(kAXSelectedTextRangeAttribute, in: element)
//        debugLog("\(label): role=\(role) subrole=\(subrole) editable=\(editable?.description ?? "nil") hasSelectedTextRange=\(hasRange)")
    }

    // MARK: - Anchor Position via Accessibility API

    private static func getAnchorRect() -> AnchorRect? {
        debugLog("AXIsProcessTrusted = \(AXIsProcessTrusted())")
        guard let app = NSWorkspace.shared.frontmostApplication else {
            debugLog("No frontmost app")
            return nil
        }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        debugLog("Frontmost app: \(app.localizedName ?? "unknown") (pid \(app.processIdentifier))")

        var focusedElement: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard focusResult == .success else {
            debugLog("Failed to get focused element: \(focusResult.rawValue)")
            return nil
        }
        let focusedAXElement = focusedElement as! AXUIElement
        dumpElementInfo("Focused element", focusedAXElement)

        // 1. Try caret on focused element directly
        if let caretAnchor = caretAnchorRect(for: focusedAXElement, source: .caret) {
            debugLog("Anchor source: caret (direct)")
            return caretAnchor
        }

        // 2. Search CHILDREN of focused element for an editable node (WebView case)
        //    Skip for browsers — their AX trees are too deep and cause stack overflow.
        let isBrowser = Self.browserBundleIDs.contains(app.bundleIdentifier ?? "")
        if !isBrowser, let childResult = findEditableInChildren(of: focusedAXElement, maxDepth: 2) {
            dumpElementInfo("Found editable child", childResult)
            if let caretAnchor = caretAnchorRect(for: childResult, source: .caretViaChild) {
                debugLog("Anchor source: caret (via child)")
                return caretAnchor
            }
        }

        // 3. Walk PARENT chain to find a text input element
        if let axElement = nearestTextInputElement(from: focusedAXElement) {
            dumpElementInfo("Found parent text input", axElement)
            if let caretAnchor = caretAnchorRect(for: axElement, source: .caretViaParent) {
                debugLog("Anchor source: caret (via parent)")
                return caretAnchor
            }

            // Fallback to the focused input element frame
            if let inputFrame = frame(of: axElement) {
                if inputFrame.height <= 140 && inputFrame.width <= 1600 {
                    debugLog("Anchor source: inputFrame (\(inputFrame))")
                    return AnchorRect(rect: inputFrame, prefersLeadingEdge: false, source: .inputFrame)
                }
                debugLog("Input frame too large (\(inputFrame.size)), skipping")
            }
        }

        // 4. Fallback: anchor near the bottom composer region of the focused window
        debugLog("Anchor source: windowComposerFallback")
        return focusedWindowComposerAnchor(for: axApp)
    }

    private static func origin(for anchor: AnchorRect?, windowSize: NSSize, screenFrame: NSRect) -> NSPoint {
        guard let anchor else {
            debugLog("Anchor source: screenCenter")
            return screenCenter()
        }
        debugLog("Using anchor source: \(anchor.source.rawValue) rect=\(anchor.rect)")

        let convertedRect = convertAccessibilityRect(anchor.rect)
        let x = anchor.prefersLeadingEdge ? convertedRect.minX : convertedRect.minX + 8
        var origin = NSPoint(x: x, y: convertedRect.maxY - windowSize.height - 8)

        if origin.y < screenFrame.minY {
            origin.y = convertedRect.minY + 8
        }
        if origin.x + windowSize.width > screenFrame.maxX {
            origin.x = screenFrame.maxX - windowSize.width
        }
        if origin.x < screenFrame.minX {
            origin.x = screenFrame.minX
        }
        if origin.y + windowSize.height > screenFrame.maxY {
            origin.y = screenFrame.maxY - windowSize.height
        }

        return origin
    }

    private static func convertAccessibilityRect(_ rect: CGRect) -> CGRect {
        // AX coordinates: origin at top-left of PRIMARY screen, Y increases downward.
        // AppKit coordinates: origin at bottom-left of PRIMARY screen, Y increases upward.
        // The correct pivot is the primary screen height (screens[0]), NOT the max Y across all screens.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? NSScreen.main?.frame.height ?? 0
        debugLog("convertAXRect: input=\(rect) primaryHeight=\(primaryHeight)")
        return CGRect(
            x: rect.origin.x,
            y: primaryHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    private static func screen(containing rect: CGRect) -> NSScreen? {
        let convertedRect = convertAccessibilityRect(rect)
        let point = NSPoint(x: convertedRect.midX, y: convertedRect.midY)
        return NSScreen.screens.first(where: { $0.frame.contains(point) })
    }

    private static func isTextInputCandidate(role: String?, subrole: String?, isEditable: Bool) -> Bool {
        if isEditable {
            return true
        }

        guard let role else { return false }
        if textInputRoles.contains(role) {
            return true
        }
        if let subrole, textInputRoles.contains(subrole) {
            return true
        }
        return false
    }

    private static func nearestTextInputElement(from element: AXUIElement) -> AXUIElement? {
        var current: AXUIElement? = element
        var depth = 0

        while let node = current, depth < 8 {
            let role = stringValue(for: kAXRoleAttribute, in: node)
            let subrole = stringValue(for: kAXSubroleAttribute, in: node)
            let isEditable = boolValue(for: axEditableAttribute, in: node) ?? false

            if isTextInputCandidate(role: role, subrole: subrole, isEditable: isEditable) {
                return node
            }

            current = parentElement(of: node)
            depth += 1
        }

        return nil
    }

    private static func caretAnchorRect(for element: AXUIElement, source: AnchorSource = .caret) -> AnchorRect? {
        var selectedRange: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRange)
        guard rangeResult == .success, let range = selectedRange else { return nil }

        var bounds: AnyObject?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            range,
            &bounds
        )
        guard boundsResult == .success, let boundsValue = bounds else { return nil }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect) else { return nil }
        guard rect.width >= 0, rect.height >= 0 else { return nil }

        return AnchorRect(rect: rect, prefersLeadingEdge: true, source: source)
    }

    /// Search children of an element (breadth-first) for an editable text node.
    /// This handles WebView/browser cases where the focused element is a WebArea
    /// container and the actual editable node is a child.
    private static func findEditableInChildren(of element: AXUIElement, maxDepth: Int) -> AXUIElement? {
        guard maxDepth > 0 else { return nil }

        var childrenValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue)
        guard result == .success, let children = childrenValue as? [AXUIElement] else { return nil }

        // First pass: check immediate children
        for child in children {
            let role = stringValue(for: kAXRoleAttribute, in: child)
            let subrole = stringValue(for: kAXSubroleAttribute, in: child)
            let isEditable = boolValue(for: axEditableAttribute, in: child) ?? false

            if isEditable || isTextInputCandidate(role: role, subrole: subrole, isEditable: isEditable) {
                // Verify it can actually provide caret bounds
                if hasAttribute(kAXSelectedTextRangeAttribute, in: child) {
                    return child
                }
            }
        }

        // Second pass: recurse into children (limit breadth to avoid Chrome AX tree explosion)
        for child in children.prefix(5) {
            if let found = findEditableInChildren(of: child, maxDepth: maxDepth - 1) {
                return found
            }
        }

        return nil
    }

    private static func hasAttribute(_ attribute: String, in element: AXUIElement) -> Bool {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return result == .success
    }

    private static func focusedWindowComposerAnchor(for app: AXUIElement) -> AnchorRect? {
        var focusedWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        guard result == .success, let window = focusedWindow else { return nil }

        let windowElement = window as! AXUIElement
        guard let windowRect = frame(of: windowElement) else { return nil }

        // For chat-style apps (Slack, Codex, etc.), the input is typically near the bottom.
        // In AX coordinates (top-left origin, Y increases downward):
        //   windowRect.origin.y = top of window
        //   windowRect.maxY = bottom of window
        // Anchor near the bottom of the window (80px from bottom) for composer-style inputs.
        let anchorHeight: CGFloat = 44
        let leadingInset = min(max(24, windowRect.width * 0.22), 320)
        let anchorWidth = max(320, min(windowRect.width - leadingInset - 32, 760))
        let anchorX = windowRect.minX + leadingInset
        let anchorY = windowRect.maxY - 80 - anchorHeight

        debugLog("Window composer fallback: windowRect=\(windowRect) anchorY=\(anchorY)")

        return AnchorRect(
            rect: CGRect(x: anchorX, y: anchorY, width: anchorWidth, height: anchorHeight),
            prefersLeadingEdge: true,
            source: .windowComposerFallback
        )
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: AnyObject?
        let posResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue)
        guard posResult == .success, let posVal = positionValue else { return nil }

        var point = CGPoint.zero
        guard AXValueGetValue(posVal as! AXValue, .cgPoint, &point) else { return nil }

        var sizeValue: AnyObject?
        let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)
        guard sizeResult == .success, let sizeVal = sizeValue else { return nil }

        var size = CGSize.zero
        guard AXValueGetValue(sizeVal as! AXValue, .cgSize, &size) else { return nil }

        return CGRect(origin: point, size: size)
    }

    private static func parentElement(of element: AXUIElement) -> AXUIElement? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &value)
        guard result == .success, let parent = value else { return nil }
        return parent as! AXUIElement
    }

    private static func stringValue(for attribute: String, in element: AXUIElement) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    private static func boolValue(for attribute: String, in element: AXUIElement) -> Bool? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? Bool
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
