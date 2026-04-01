//
//  QuickPasteView.swift
//  Paste
//

import SwiftUI

struct QuickPasteView: View {
    @ObservedObject var clipboardService: ClipboardService
    let onSelect: (ClipboardItem) -> Void
    let onDismiss: () -> Void

    @State private var selectedIndex: Int = 0
    @State private var keyMonitor: Any?

    var items: [ClipboardItem] {
        Array(clipboardService.clipboardHistory.prefix(10))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "clipboard")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("Quick Paste")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("ESC to close")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 28, weight: .thin))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No clipboard history")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                QuickPasteRow(
                                    item: item,
                                    index: index + 1,
                                    isSelected: index == selectedIndex
                                )
                                .id(index)
                                .onTapGesture {
                                    onSelect(item)
                                }
                                .onHover { hovering in
                                    if hovering { selectedIndex = index }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: selectedIndex) { newIndex in
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 320)
        .frame(maxHeight: 400)
        .fixedSize(horizontal: false, vertical: true)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            selectedIndex = 0
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                let itemCount = items.count
                guard itemCount > 0 else {
                    if event.keyCode == 53 { // Esc
                        onDismiss()
                        return nil
                    }
                    return event
                }

                // Number keys 1-9 for quick select
                if !event.modifierFlags.contains(.command),
                   let chars = event.charactersIgnoringModifiers,
                   let digit = Int(chars), digit >= 1, digit <= 9 {
                    let idx = digit - 1
                    if idx < itemCount {
                        onSelect(items[idx])
                    }
                    return nil
                }

                switch event.keyCode {
                case 126: // Up
                    selectedIndex = max(0, selectedIndex - 1)
                    return nil
                case 125: // Down
                    selectedIndex = min(itemCount - 1, selectedIndex + 1)
                    return nil
                case 36: // Enter
                    if selectedIndex < itemCount {
                        onSelect(items[selectedIndex])
                    }
                    return nil
                case 53: // Esc
                    onDismiss()
                    return nil
                default:
                    return event
                }
            }
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }
    }
}

struct QuickPasteRow: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Index badge
            Text("\(index)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 18, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )

            // Content
            if item.isImage, let data = item.imageData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text("Image")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                Text(item.content.components(separatedBy: .newlines).first ?? item.content)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            Text(item.timestamp, style: .time)
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .padding(.horizontal, 4)
    }
}
