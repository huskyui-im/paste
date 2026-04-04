//
//  PasteInputMethodCandidateController.swift
//  PasteInputMethodPrototype
//

import AppKit
import InputMethodKit

final class PasteInputMethodCandidateController {
    private let store: PasteInputMethodClipboardStore
    private let candidateWindow: IMKCandidates
    private(set) var currentItems: [PasteInputMethodCandidateItem] = []

    init(server: IMKServer, store: PasteInputMethodClipboardStore) {
        self.store = store
        self.candidateWindow = IMKCandidates(
            server: server,
            panelType: kIMKSingleColumnScrollingCandidatePanel,
            styleType: kIMKMain
        )
        candidateWindow.setSelectionKeys([18, 19, 20, 21, 23, 22, 26, 28, 25])
        candidateWindow.setDismissesAutomatically(true)
        candidateWindow.setAttributes([
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 14),
            IMKCandidatesOpacityAttributeName: NSNumber(value: 0.96)
        ])
    }

    func refreshItems() {
        currentItems = store.loadCandidates()
        candidateWindow.update()
    }

    func show() {
        refreshItems()
        guard !currentItems.isEmpty else { return }
        candidateWindow.show(kIMKLocateCandidatesBelowHint)
    }

    func hide() {
        candidateWindow.hide()
    }

    func candidateStrings() -> [NSAttributedString] {
        currentItems.map { item in
            let line = item.content.components(separatedBy: .newlines).first ?? item.content
            return NSAttributedString(string: String(line.prefix(80)))
        }
    }

    func item(for candidate: NSAttributedString?) -> PasteInputMethodCandidateItem? {
        guard let candidate,
              let index = candidateStrings().enumerated().first(where: { $0.element.string == candidate.string })?.offset,
              currentItems.indices.contains(index) else {
            return nil
        }
        return currentItems[index]
    }

    func commit(_ item: PasteInputMethodCandidateItem, to client: any NSObjectProtocol & IMKTextInput) {
        store.copyToPasteboard(item.content)
        client.insertText(item.content, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
    }
}

