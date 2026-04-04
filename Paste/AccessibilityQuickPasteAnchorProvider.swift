//
//  AccessibilityQuickPasteAnchorProvider.swift
//  Paste
//

import Cocoa

final class AccessibilityQuickPasteAnchorProvider: QuickPasteAnchorProviding {
    private let axEditableAttribute = "AXEditable"

    private let browserBundleIDs: Set<String> = [
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

    private let textInputRoles: Set<String> = [
        kAXTextFieldRole as String,
        kAXTextAreaRole as String,
        kAXSearchFieldSubrole as String,
        kAXComboBoxRole as String
    ]

    func prepareIfNeeded() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }

    func anchorForFrontmostApp() -> QuickPasteAnchor? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }

        if browserBundleIDs.contains(app.bundleIdentifier ?? "") {
            return nil
        }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var focusedElement: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard focusResult == .success, let focusedElement else { return focusedWindowComposerAnchor(for: axApp) }

        let focusedAXElement = focusedElement as! AXUIElement

        if let caretAnchor = caretAnchorRect(for: focusedAXElement, source: "focused-caret") {
            return caretAnchor
        }

        if let childResult = findEditableInChildren(of: focusedAXElement, maxDepth: 2),
           let caretAnchor = caretAnchorRect(for: childResult, source: "child-caret") {
            return caretAnchor
        }

        if let textInput = nearestTextInputElement(from: focusedAXElement) {
            if let caretAnchor = caretAnchorRect(for: textInput, source: "parent-caret") {
                return caretAnchor
            }

            if let inputFrame = frame(of: textInput), inputFrame.height <= 140, inputFrame.width <= 1600 {
                return QuickPasteAnchor(rect: inputFrame, prefersLeadingEdge: false, source: "input-frame")
            }
        }

        return focusedWindowComposerAnchor(for: axApp)
    }

    private func nearestTextInputElement(from element: AXUIElement) -> AXUIElement? {
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

    private func caretAnchorRect(for element: AXUIElement, source: String) -> QuickPasteAnchor? {
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

        return QuickPasteAnchor(rect: rect, prefersLeadingEdge: true, source: source)
    }

    private func findEditableInChildren(of element: AXUIElement, maxDepth: Int) -> AXUIElement? {
        guard maxDepth > 0 else { return nil }

        var childrenValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue)
        guard result == .success, let children = childrenValue as? [AXUIElement] else { return nil }

        for child in children {
            let role = stringValue(for: kAXRoleAttribute, in: child)
            let subrole = stringValue(for: kAXSubroleAttribute, in: child)
            let isEditable = boolValue(for: axEditableAttribute, in: child) ?? false

            if isEditable || isTextInputCandidate(role: role, subrole: subrole, isEditable: isEditable) {
                if hasAttribute(kAXSelectedTextRangeAttribute, in: child) {
                    return child
                }
            }
        }

        for child in children.prefix(5) {
            if let found = findEditableInChildren(of: child, maxDepth: maxDepth - 1) {
                return found
            }
        }

        return nil
    }

    private func focusedWindowComposerAnchor(for app: AXUIElement) -> QuickPasteAnchor? {
        var focusedWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        guard result == .success, let focusedWindow else { return nil }

        let windowElement = focusedWindow as! AXUIElement
        guard let windowRect = frame(of: windowElement) else { return nil }

        let anchorHeight: CGFloat = 44
        let leadingInset = min(max(24, windowRect.width * 0.22), 320)
        let anchorWidth = max(320, min(windowRect.width - leadingInset - 32, 760))
        let anchorX = windowRect.minX + leadingInset
        let anchorY = windowRect.maxY - 80 - anchorHeight

        return QuickPasteAnchor(
            rect: CGRect(x: anchorX, y: anchorY, width: anchorWidth, height: anchorHeight),
            prefersLeadingEdge: true,
            source: "window-composer"
        )
    }

    private func frame(of element: AXUIElement) -> CGRect? {
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

    private func parentElement(of element: AXUIElement) -> AXUIElement? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &value)
        guard result == .success, let parent = value else { return nil }
        return parent as! AXUIElement
    }

    private func stringValue(for attribute: String, in element: AXUIElement) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    private func boolValue(for attribute: String, in element: AXUIElement) -> Bool? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? Bool
    }

    private func hasAttribute(_ attribute: String, in element: AXUIElement) -> Bool {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return result == .success
    }

    private func isTextInputCandidate(role: String?, subrole: String?, isEditable: Bool) -> Bool {
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
}

