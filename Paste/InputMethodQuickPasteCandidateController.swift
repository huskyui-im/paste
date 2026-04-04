//
//  InputMethodQuickPasteCandidateController.swift
//  Paste
//

import AppKit
import InputMethodKit

final class InputMethodQuickPasteCandidateController {
    private let candidateWindow: IMKCandidates
    private let clipboardServiceProvider: () -> ClipboardService?
    private(set) var currentItems: [ClipboardItem] = []

    init(server: IMKServer, clipboardServiceProvider: @escaping () -> ClipboardService?) {
        self.clipboardServiceProvider = clipboardServiceProvider
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
        currentItems = Array(clipboardServiceProvider()?.clipboardHistory.prefix(9) ?? [])
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
            let title: String
            if item.isImage {
                title = "[图片]"
            } else {
                title = item.content
                    .components(separatedBy: .newlines)
                    .first?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .prefix(80)
                    .description ?? item.content
            }
            return NSAttributedString(string: title)
        }
    }

    func item(for candidate: NSAttributedString?) -> ClipboardItem? {
        guard let candidate else { return nil }
        guard let index = candidateStrings()
            .enumerated()
            .first(where: { $0.element.string == candidate.string })?
            .offset,
              currentItems.indices.contains(index) else {
            return nil
        }
        return currentItems[index]
    }
}
