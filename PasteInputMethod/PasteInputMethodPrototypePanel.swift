//
//  PasteInputMethodPrototypePanel.swift
//  PasteInputMethodPrototype
//

import AppKit
import SwiftUI

final class PasteInputMethodPrototypePanelModel: ObservableObject {
    @Published var items: [PasteInputMethodCandidateItem] = []
}

struct PasteInputMethodPrototypePanelView: View {
    private enum SelectionSource {
        case initial
        case pointer
        case keyboard
    }

    @ObservedObject var model: PasteInputMethodPrototypePanelModel
    let onSelect: (PasteInputMethodCandidateItem) -> Void
    let onDismiss: () -> Void

    @State private var selectedIndex: Int = 0
    @State private var selectionSource: SelectionSource = .initial

    private var items: [PasteInputMethodCandidateItem] {
        model.items
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "character.cursor.ibeam")
                    .foregroundColor(.secondary)
                Text("Input Method Prototype")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("ESC")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 28, weight: .thin))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No clipboard items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            HStack(spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 18, height: 18)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(Color.primary.opacity(0.06))
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(item.content.prefix(80)))
                                        .font(.system(size: 12))
                                        .lineLimit(1)
                                    Text(item.timestamp, style: .time)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(index == selectedIndex ? Color.accentColor.opacity(0.16) : Color.clear)
                            )
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(item) }
                            .onHover { hovering in
                                guard hovering else { return }
                                updateSelectedIndex(index, source: .pointer)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(width: 340)
        .frame(maxHeight: 420)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .onChange(of: items.count) {
            if items.isEmpty {
                updateSelectedIndex(0, source: .initial)
            } else {
                updateSelectedIndex(min(selectedIndex, items.count - 1), source: .initial)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pasteInputMethodPrototypeKeyEvent)) { notification in
            guard let userInfo = notification.userInfo,
                  let keyCode = userInfo["keyCode"] as? UInt16,
                  let characters = userInfo["characters"] as? String else { return }

            if keyCode == 53 {
                onDismiss()
                return
            }

            guard !items.isEmpty else { return }

            if let digit = Int(characters), digit >= 1, digit <= 9 {
                let index = digit - 1
                if index < items.count {
                    onSelect(items[index])
                }
                return
            }

            switch keyCode {
            case 126:
                updateSelectedIndex(max(0, selectedIndex - 1), source: .keyboard)
            case 125:
                updateSelectedIndex(min(items.count - 1, selectedIndex + 1), source: .keyboard)
            case 36:
                onSelect(items[selectedIndex])
            default:
                break
            }
        }
    }

    private func updateSelectedIndex(_ newIndex: Int, source: SelectionSource) {
        guard selectedIndex != newIndex || selectionSource != source else { return }

        var transaction = Transaction()
        transaction.animation = source == .keyboard ? .easeOut(duration: 0.1) : nil

        withTransaction(transaction) {
            selectionSource = source
            selectedIndex = newIndex
        }
    }
}

final class PasteInputMethodPrototypePanelController: NSPanel {
    private let store: PasteInputMethodClipboardStore
    private let model = PasteInputMethodPrototypePanelModel()
    private var previousApp: NSRunningApplication?
    private var clickMonitor: Any?
    private var keyMonitor: Any?

    init(store: PasteInputMethodClipboardStore) {
        self.store = store

        let items = store.loadCandidates()
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 420),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true

        model.items = items
        rebuildContent()
    }

    func toggle() {
        isVisible ? dismiss() : show()
    }

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication
        model.items = store.loadCandidates()

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 900, height: 700)
        let origin = NSPoint(x: screen.midX - 170, y: screen.midY - 120)
        setFrameOrigin(origin)
        orderFrontRegardless()

        if let app = previousApp {
            app.activate()
        }

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.isVisible else { return }
            if !NSPointInRect(NSEvent.mouseLocation, self.frame) {
                self.dismiss()
            }
        }

        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isVisible else { return }
            NotificationCenter.default.post(
                name: .pasteInputMethodPrototypeKeyEvent,
                object: nil,
                userInfo: [
                    "keyCode": event.keyCode,
                    "characters": event.charactersIgnoringModifiers ?? ""
                ]
            )
        }
    }

    func dismiss() {
        orderOut(nil)
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func rebuildContent() {
        let view = PasteInputMethodPrototypePanelView(
            model: model,
            onSelect: { [weak self] item in
                self?.handleSelection(item)
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )
        contentViewController = NSHostingController(rootView: view)
    }

    private func handleSelection(_ item: PasteInputMethodCandidateItem) {
        store.copyToPasteboard(item.content)
        dismiss()

        if let app = previousApp {
            app.activate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            Self.simulatePaste()
        }
    }

    private static func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

extension Notification.Name {
    static let pasteInputMethodPrototypeKeyEvent = Notification.Name("pasteInputMethodPrototypeKeyEvent")
}
