//
//  InputMethodQuickPastePrototype.swift
//  Paste
//

import Foundation

struct InputMethodPrototypeStatus {
    let mode: QuickPasteArchitectureMode
    let isReadyForSystemWideCaretTracking: Bool
    let nextMilestones: [String]
}

final class InputMethodQuickPastePrototype {
    var status: InputMethodPrototypeStatus {
        InputMethodPrototypeStatus(
            mode: .inputMethodPrototype,
            isReadyForSystemWideCaretTracking: false,
            nextMilestones: [
                "Create a dedicated InputMethodKit target instead of reusing the menu bar app target",
                "Move candidate UI ownership from QuickPasteWindow to an IMK candidate controller",
                "Route clipboard selection actions through the input method candidate session"
            ]
        )
    }

    func makeAnchorProvider() -> QuickPasteAnchorProviding {
        InputMethodPrototypeAnchorProvider()
    }
}

private struct InputMethodPrototypeAnchorProvider: QuickPasteAnchorProviding {
    func anchorForFrontmostApp() -> QuickPasteAnchor? {
        nil
    }
}
