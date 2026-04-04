//
//  PasteInputMethodController.swift
//  Paste
//

import AppKit
import InputMethodKit

final class PasteInputMethodController: IMKInputController {
    static var clipboardServiceProvider: () -> ClipboardService? = { nil }

    private lazy var quickPasteCandidates = InputMethodQuickPasteCandidateController(
        server: server(),
        clipboardServiceProvider: Self.clipboardServiceProvider
    )

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard event.type == .keyDown else { return false }

        let wantsQuickPaste =
            event.modifierFlags.contains(.command) &&
            event.modifierFlags.contains(.shift) &&
            event.keyCode == UInt16(kVK_ANSI_V)

        guard wantsQuickPaste else { return false }

        quickPasteCandidates.show()
        return true
    }

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        quickPasteCandidates.refreshItems()
    }

    override func deactivateServer(_ sender: Any!) {
        quickPasteCandidates.hide()
        super.deactivateServer(sender)
    }

    override func candidates(_ sender: Any!) -> [Any]! {
        quickPasteCandidates.candidateStrings()
    }

    override func candidateSelected(_ candidateString: NSAttributedString!) {
        guard let item = quickPasteCandidates.item(for: candidateString) else { return }

        if item.isImage, let data = item.imageData {
            Self.clipboardServiceProvider()?.copyImageToClipboard(data)
        } else {
            Self.clipboardServiceProvider()?.copyToClipboard(item.content)
            client().insertText(item.content, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        }

        quickPasteCandidates.hide()
    }

    override func hidePalettes() {
        quickPasteCandidates.hide()
        super.hidePalettes()
    }
}
