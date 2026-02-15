//
//  PasteApp.swift
//  Paste
//
//  Created by 王鹏 on 2025/11/2.
//

import SwiftUI

@main
struct PasteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
