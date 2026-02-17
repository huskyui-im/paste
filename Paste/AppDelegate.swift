//
//  AppDelegate.swift
//  Paste
//
//  Created by 王鹏 on 2025/11/2.
//
import Cocoa
import SwiftUI
import Carbon
import ServiceManagement
import ScreenCaptureKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var hotKeyRef: EventHotKeyRef?
    var screenshotHotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 隐藏 Dock 图标，仅以状态栏模式运行
        NSApp.setActivationPolicy(.accessory)

        // 创建状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Clipboard Manager")
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // 设置右键菜单
        setupMenu()

        // 设置弹出窗口
        setupPopover()

        // 注册全局快捷键 Command+Shift+P
        registerHotKey()

        // 启动时预请求屏幕录制权限（触发系统授权弹窗）
        requestScreenCapturePermission()
    }

    private func requestScreenCapturePermission() {
        Task {
            do {
                // 调用 SCShareableContent 会触发系统屏幕录制权限弹窗
                _ = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            } catch {
                print("屏幕录制权限请求失败: \(error)")
            }
        }
    }

    func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 500, height: 600)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView())
    }

    func setupMenu() {
        let menu = NSMenu()

        let launchItem = NSMenuItem(title: "开机启动", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchItem.target = self
        if SMAppService.mainApp.status == .enabled {
            launchItem.state = .on
        }
        menu.addItem(launchItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "退出 Paste", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = nil // 默认左键弹 popover，右键弹菜单由 togglePopover 处理
        self.statusMenu = menu
    }

    var statusMenu: NSMenu?

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }

        // 右键显示菜单
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            if let menu = statusMenu {
                // 刷新开机启动状态
                if let launchItem = menu.items.first {
                    launchItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
                }
                statusItem.menu = menu
                button.performClick(nil)
                statusItem.menu = nil // 恢复左键点击行为
            }
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            // 点击外部区域关闭
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                sender.state = .off
            } else {
                try SMAppService.mainApp.register()
                sender.state = .on
            }
        } catch {
            print("开机启动设置失败: \(error)")
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    func registerHotKey() {
        // 安装 Carbon 事件处理器
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()

            // 获取热键 ID 以区分不同快捷键
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)

            DispatchQueue.main.async {
                switch hotKeyID.id {
                case 1:
                    appDelegate.togglePopover()
                case 2:
                    appDelegate.startScreenshot()
                default:
                    break
                }
            }
            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, selfPtr, nil)

        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)

        // Command+Shift+P: keyCode 35 (kVK_ANSI_P) — 打开剪贴板
        let hotKeyID1 = EventHotKeyID(signature: OSType(0x50535445), id: 1) // "PSTE"
        RegisterEventHotKey(UInt32(kVK_ANSI_P), modifiers, hotKeyID1, GetApplicationEventTarget(), 0, &hotKeyRef)

        // Command+Shift+S: keyCode 1 (kVK_ANSI_S) — 截图
        let hotKeyID2 = EventHotKeyID(signature: OSType(0x50535445), id: 2)
        RegisterEventHotKey(UInt32(kVK_ANSI_S), modifiers, hotKeyID2, GetApplicationEventTarget(), 0, &screenshotHotKeyRef)
    }

    func startScreenshot() {
        ScreenshotService.shared.startCapture()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let screenshotHotKeyRef = screenshotHotKeyRef {
            UnregisterEventHotKey(screenshotHotKeyRef)
        }
    }
}
