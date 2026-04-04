//
//  QuickPasteAnchoring.swift
//  Paste
//

import Cocoa

struct QuickPasteAnchor {
    let rect: CGRect
    let prefersLeadingEdge: Bool
    let source: String
}

protocol QuickPasteAnchorProviding {
    func prepareIfNeeded()
    func anchorForFrontmostApp() -> QuickPasteAnchor?
}

extension QuickPasteAnchorProviding {
    func prepareIfNeeded() {}
}

enum QuickPasteArchitectureMode: String {
    case accessibilityWindow = "accessibility-window"
    case inputMethodPrototype = "input-method-prototype"
}

