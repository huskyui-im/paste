//
//  AppDelegate.swift
//  Paste
//
//  Created by 王鹏 on 2025/11/2.
//
import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Clipboard Manager")
            button.action = #selector(togglePopover)
        }
        
        // 设置弹出窗口
        setupPopover()
        
        // 隐藏主窗口（因为我们使用状态栏）
        if let window = NSApplication.shared.windows.first {
            window.close()
        }
    }
    
    func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 500, height: 600)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView())
    }
    
    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            
            // 点击外部区域关闭
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 清理资源
    }
}
