//
//  ScreenshotService.swift
//  Paste
//
//  截图服务：全屏遮罩 + 拖拽选区 + 截图到剪贴板
//

import Cocoa
import ScreenCaptureKit

class ScreenshotService {
    static let shared = ScreenshotService()
    private var overlayWindows: [ScreenshotOverlayWindow] = []

    func startCapture() {
        // 为每个屏幕创建遮罩窗口
        for screen in NSScreen.screens {
            let window = ScreenshotOverlayWindow(screen: screen)
            overlayWindows.append(window)
            window.makeKeyAndOrderFront(nil)
        }
        // 激活应用以接收键盘事件
        NSApp.activate(ignoringOtherApps: true)
    }

    func cancelCapture() {
        closeAllOverlays()
    }

    func finishCapture(rect: CGRect, screen: NSScreen) {
        // 先关闭遮罩窗口，避免截到遮罩本身
        closeAllOverlays()

        // 稍微延迟以确保窗口已完全消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.captureScreen(rect: rect, screen: screen)
        }
    }

    private func closeAllOverlays() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }

    private func captureScreen(rect: CGRect, screen: NSScreen) {
        // rect 是全局 NSScreen 坐标（左下角原点）
        // 需要转换为 display-local 坐标（左上角原点，相对于该显示器）
        let screenFrame = screen.frame
        let mainScreenHeight = NSScreen.screens.first?.frame.height ?? screenFrame.height

        // 先算出相对于该显示器的局部坐标（NSScreen 坐标系，左下角原点）
        let localX = rect.origin.x - screenFrame.origin.x
        let localY = rect.origin.y - screenFrame.origin.y

        // 转换为左上角原点坐标系（SCKit / CoreGraphics 使用左上角原点）
        let flippedY = screenFrame.height - localY - rect.height

        let sourceRect = CGRect(
            x: localX,
            y: flippedY,
            width: rect.width,
            height: rect.height
        )

        guard sourceRect.width > 1, sourceRect.height > 1 else { return }

        // 使用 ScreenCaptureKit 截图
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

                // 找到对应的 SCDisplay
                let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? CGMainDisplayID()
                guard let scDisplay = content.displays.first(where: { $0.displayID == displayID }) else {
                    print("截图失败: 找不到对应的 SCDisplay")
                    return
                }

                // 排除自身应用窗口
                let excludedApps = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }

                let filter = SCContentFilter(display: scDisplay, excludingApplications: excludedApps, exceptingWindows: [])
                let config = SCStreamConfiguration()
                let scale = screen.backingScaleFactor
                config.sourceRect = sourceRect
                config.width = max(1, Int(sourceRect.width * scale))
                config.height = max(1, Int(sourceRect.height * scale))
                config.showsCursor = false
                config.captureResolution = .best
                config.pixelFormat = kCVPixelFormatType_32BGRA

                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

                let bitmapRep = NSBitmapImageRep(cgImage: image)
                guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }

                // 同时写入 PNG 和 TIFF 到剪贴板，兼容更多应用
                await MainActor.run {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setData(pngData, forType: .png)
                    if let tiffData = bitmapRep.tiffRepresentation {
                        pasteboard.setData(tiffData, forType: .tiff)
                    }
                }
            } catch {
                print("截图失败: \(error)")
            }
        }
    }
}

// MARK: - 全屏遮罩窗口

class ScreenshotOverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        self.level = .screenSaver
        self.isOpaque = false
        self.hasShadow = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.contentView = ScreenshotOverlayView(frame: screen.frame, screen: screen)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - 遮罩视图（绘制半透明遮罩 + 选区）

class ScreenshotOverlayView: NSView {
    private var selectionStart: NSPoint?
    private var selectionRect: NSRect?
    private let overlayColor = NSColor.black.withAlphaComponent(0.3)
    private let screen: NSScreen

    init(frame: NSRect, screen: NSScreen) {
        self.screen = screen
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // 绘制半透明遮罩
        overlayColor.setFill()
        dirtyRect.fill()

        // 如果有选区，清除选区区域并绘制边框
        if let selection = selectionRect {
            // 清除选区内的遮罩，露出原始屏幕
            NSColor.clear.setFill()
            selection.fill(using: .copy)

            // 绘制选区边框
            let borderPath = NSBezierPath(rect: selection)
            NSColor.white.withAlphaComponent(0.8).setStroke()
            borderPath.lineWidth = 1.5
            borderPath.stroke()
        }
    }

    // MARK: - 鼠标事件

    override func mouseDown(with event: NSEvent) {
        selectionStart = convert(event.locationInWindow, from: nil)
        selectionRect = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = selectionStart else { return }
        let current = convert(event.locationInWindow, from: nil)

        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let w = abs(current.x - start.x)
        let h = abs(current.y - start.y)

        selectionRect = NSRect(x: x, y: y, width: w, height: h)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let selection = selectionRect, selection.width > 2, selection.height > 2 else {
            // 选区太小，忽略
            selectionStart = nil
            selectionRect = nil
            needsDisplay = true
            return
        }

        // 将视图坐标转换为屏幕坐标
        let screenFrame = screen.frame
        let screenRect = NSRect(
            x: screenFrame.origin.x + selection.origin.x,
            y: screenFrame.origin.y + selection.origin.y,
            width: selection.width,
            height: selection.height
        )

        ScreenshotService.shared.finishCapture(rect: screenRect, screen: screen)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            ScreenshotService.shared.cancelCapture()
        }
    }

    override var acceptsFirstResponder: Bool { true }
}
