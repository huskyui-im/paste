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
    private let anchorProvider: QuickPasteAnchorProviding

    init(clipboardService: ClipboardService, anchorProvider: QuickPasteAnchorProviding) {
        self.anchorProvider = anchorProvider

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

    func showAtCaretOrCenter() {
        anchorProvider.prepareIfNeeded()
        previousApp = NSWorkspace.shared.frontmostApplication

        if let hostingView = self.contentViewController as? NSHostingController<QuickPasteView> {
            let fittingSize = hostingView.sizeThatFits(in: NSSize(width: 320, height: 400))
            self.setContentSize(fittingSize)
        }

        let windowSize = self.frame.size
        let anchor = anchorProvider.anchorForFrontmostApp()
        let screenFrame = anchor.flatMap { Self.screen(containing: $0.rect) }?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let origin = Self.origin(for: anchor, windowSize: windowSize, screenFrame: screenFrame)

        self.setFrameOrigin(origin)
        self.orderFrontRegardless()

        if let app = previousApp {
            app.activate()
        }

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isVisible else { return }
            let windowFrame = self.frame
            let _ = event.locationInWindow
            if !NSPointInRect(NSEvent.mouseLocation, windowFrame) {
                self.dismiss()
            }
        }

        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isVisible else { return }
            self.handleKeyEvent(event)
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        NotificationCenter.default.post(
            name: .quickPasteKeyEvent,
            object: nil,
            userInfo: [
                "keyCode": event.keyCode,
                "characters": event.charactersIgnoringModifiers ?? "",
                "modifierFlags": event.modifierFlags.rawValue
            ]
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
        if item.isImage, let data = item.imageData {
            clipboardService.copyImageToClipboard(data)
        } else {
            clipboardService.copyToClipboard(item.content)
        }

        dismiss()

        if let app = previousApp {
            app.activate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            Self.simulatePaste()
        }
    }

    private static func origin(for anchor: QuickPasteAnchor?, windowSize: NSSize, screenFrame: NSRect) -> NSPoint {
        guard let anchor else { return screenCenter() }

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
        let primaryHeight = NSScreen.screens.first?.frame.height ?? NSScreen.main?.frame.height ?? 0
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

    static func screenCenter() -> NSPoint {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        return NSPoint(x: screen.midX - 160, y: screen.midY + 200)
    }

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
