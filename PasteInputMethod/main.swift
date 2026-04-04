//
//  main.swift
//  PasteInputMethodPrototype
//

import AppKit

let application = NSApplication.shared
let delegate = PasteInputMethodAppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()

