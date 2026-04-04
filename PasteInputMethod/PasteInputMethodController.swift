//
//  PasteInputMethodController.swift
//  PasteInputMethodPrototype
//

import AppKit
import InputMethodKit

final class PasteInputMethodController: IMKInputController {
    private let store = PasteInputMethodClipboardStore()
    private lazy var candidateController = PasteInputMethodCandidateController(server: server(), store: store)

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard event.type == .keyDown else { return false }

        let triggerQuickPaste =
            event.modifierFlags.contains(.command) &&
            event.modifierFlags.contains(.shift) &&
            event.keyCode == UInt16(kVK_ANSI_V)

        guard triggerQuickPaste else { return false }
        candidateController.show()
        return true
    }

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        candidateController.refreshItems()
    }

    override func deactivateServer(_ sender: Any!) {
        candidateController.hide()
        super.deactivateServer(sender)
    }

    override func candidates(_ sender: Any!) -> [Any]! {
        candidateController.candidateStrings()
    }

    override func candidateSelected(_ candidateString: NSAttributedString!) {
        guard let item = candidateController.item(for: candidateString) else { return }
        candidateController.commit(item, to: client())
        candidateController.hide()
    }
}

