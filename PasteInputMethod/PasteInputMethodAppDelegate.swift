//
//  PasteInputMethodAppDelegate.swift
//  PasteInputMethodPrototype
//

import AppKit
import Carbon

final class PasteInputMethodAppDelegate: NSObject, NSApplicationDelegate {
    private let bootstrap = PasteInputMethodBootstrap()
    private let store = PasteInputMethodClipboardStore()
    private var statusItem: NSStatusItem?
    private var panelController: PasteInputMethodPrototypePanelController?
    private var quickPasteHotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = bootstrap.start()
        panelController = PasteInputMethodPrototypePanelController(store: store)
        setupStatusItem()
        registerHotKey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let quickPasteHotKeyRef {
            UnregisterEventHotKey(quickPasteHotKeyRef)
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "character.cursor.ibeam", accessibilityDescription: "Paste Input Method Prototype")
            button.action = #selector(togglePrototypePanel)
            button.target = self
        }
        statusItem = item
    }

    private func registerHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let appDelegate = Unmanaged<PasteInputMethodAppDelegate>.fromOpaque(userData).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            DispatchQueue.main.async {
                if hotKeyID.id == 1 {
                    appDelegate.togglePrototypePanel()
                }
            }
            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, selfPtr, nil)

        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        let hotKeyID = EventHotKeyID(signature: OSType(0x50494D4B), id: 1)
        RegisterEventHotKey(UInt32(kVK_ANSI_V), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &quickPasteHotKeyRef)
    }

    @objc
    private func togglePrototypePanel() {
        panelController?.toggle()
    }
}
