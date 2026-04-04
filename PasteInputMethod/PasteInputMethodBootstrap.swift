//
//  PasteInputMethodBootstrap.swift
//  PasteInputMethodPrototype
//

import Foundation
import InputMethodKit

final class PasteInputMethodBootstrap {
    private(set) var server: IMKServer?

    @discardableResult
    func start() -> IMKServer? {
        guard server == nil else { return server }

        let server = IMKServer(
            name: "huskyui.Paste.InputMethodConnection",
            controllerClass: PasteInputMethodController.self,
            delegateClass: PasteInputMethodController.self
        )
        self.server = server
        return server
    }
}

