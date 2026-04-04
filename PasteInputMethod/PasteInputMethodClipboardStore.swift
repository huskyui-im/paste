//
//  PasteInputMethodClipboardStore.swift
//  PasteInputMethodPrototype
//

import AppKit
import Foundation

struct PasteInputMethodCandidateItem: Codable, Equatable {
    let id: UUID
    let content: String
    let timestamp: Date
    let isPinned: Bool
}

final class PasteInputMethodClipboardStore {
    private let sourceBundleIdentifier = "huskyui.Paste"
    private let persistenceKey = "clipboardHistory"

    func loadCandidates(limit: Int = 9) -> [PasteInputMethodCandidateItem] {
        guard let defaults = UserDefaults(suiteName: sourceBundleIdentifier),
              let data = defaults.data(forKey: persistenceKey),
              let items = try? JSONDecoder().decode([PasteInputMethodCandidateItem].self, from: data) else {
            return []
        }

        return Array(items.prefix(limit))
    }

    func copyToPasteboard(_ content: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
    }
}

