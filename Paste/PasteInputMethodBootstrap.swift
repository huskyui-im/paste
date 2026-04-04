//
//  PasteInputMethodBootstrap.swift
//  Paste
//

import Foundation
import InputMethodKit

struct PasteInputMethodBundleConfiguration {
    let connectionName: String
    let bundleIdentifier: String
    let controllerClassName: String

    static let prototype = PasteInputMethodBundleConfiguration(
        connectionName: "huskyui.Paste.InputMethodConnection",
        bundleIdentifier: "huskyui.PasteInputMethod",
        controllerClassName: NSStringFromClass(PasteInputMethodController.self)
    )
}

final class PasteInputMethodBootstrap {
    private(set) var server: IMKServer?

    @discardableResult
    func start(with configuration: PasteInputMethodBundleConfiguration = .prototype) -> IMKServer? {
        guard server == nil else { return server }

        let server = IMKServer(
            name: configuration.connectionName,
            controllerClass: PasteInputMethodController.self,
            delegateClass: PasteInputMethodController.self
        )
        self.server = server
        return server
    }
}
