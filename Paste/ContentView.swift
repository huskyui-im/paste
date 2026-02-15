import SwiftUI

struct ContentView: View {
    @StateObject private var clipboardService = ClipboardService()
    @State private var searchText = ""
    @State private var showOnlyPinned = false
    @State private var keyMonitor: Any?
    
    var filteredItems: [ClipboardItem] {
        var items = clipboardService.clipboardHistory
        
        if showOnlyPinned {
            items = items.filter { $0.isPinned }
        }
        
        if !searchText.isEmpty {
            items = items.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
        }
        
        return items
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    // 搜索栏
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )
                        
                        TextField("搜索剪切板历史...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(.vertical, 6)
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor).opacity(0.9))
                    )
                    
                    Divider()
                    
                    // 工具栏
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("剪切板历史")
                                .font(.headline.weight(.semibold))
                            Text("共 \(filteredItems.count) 条记录")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("仅显示置顶", isOn: $showOnlyPinned)
                            .toggleStyle(CheckboxToggleStyle())
                        
                        Button(role: .destructive) {
                            clipboardService.clearHistory()
                        } label: {
                            Label("清空", systemImage: "trash")
                                .font(.footnote.weight(.medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red.opacity(0.8))
                    }
                }
                .padding(14)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 8)
                
                // 历史记录列表
                Group {
                    if filteredItems.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "clipboard")
                                .font(.system(size: 48, weight: .thin))
                                .foregroundColor(.secondary.opacity(0.7))
                            Text("暂无复制历史")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("复制内容将自动显示在这里，方便随时查找与复用。")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(nsColor: .textBackgroundColor).opacity(0.8))
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 14) {
                                ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                                    ClipboardItemRow(
                                        item: item,
                                        shortcutIndex: index < 9 ? index + 1 : nil,
                                        onCopy: {
                                            clipboardService.copyToClipboard(item.content)
                                        },
                                        onPin: {
                                            clipboardService.togglePin(item)
                                        },
                                        onDelete: {
                                            clipboardService.deleteItem(item)
                                        }
                                    )
                                    .contextMenu {
                                        Button("复制") {
                                            clipboardService.copyToClipboard(item.content)
                                        }
                                        Button(item.isPinned ? "取消置顶" : "置顶") {
                                            clipboardService.togglePin(item)
                                        }
                                        Button("删除") {
                                            clipboardService.deleteItem(item)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            }
            .padding(16)
            .frame(maxWidth: 520, maxHeight: .infinity)
        }
        .frame(width: 520, height: 600)
        .onAppear {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
                if event.modifierFlags.contains(.command),
                   let chars = event.charactersIgnoringModifiers,
                   let digit = Int(chars), digit >= 1 && digit <= 9 {
                    let index = digit - 1
                    let items = filteredItems
                    if index < items.count {
                        clipboardService.copyToClipboard(items[index].content)
                    }
                    return nil
                }
                return event
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

struct ClipboardItemRow: View {
    let item: ClipboardItem
    var shortcutIndex: Int? = nil
    let onCopy: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 置顶/复制按钮区域
            VStack(spacing: 6) {

                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.blue)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.12))
                        )
                }
                .buttonStyle(PlainButtonStyle())

                if let idx = shortcutIndex {
                    Text("⌘\(idx)")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondary)
                }
            }
            
            // 内容区域
            VStack(alignment: .leading, spacing: 8) {
                Text(item.content)
                    .textSelection(.enabled)
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
                    .truncationMode(.tail)
                
                HStack(spacing: 8) {
                    if item.isPinned {
                        Label("已置顶", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .imageScale(.small)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.12))
                            )
                    }
                    
                    Spacer()
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.red)
                            .frame(width: 26, height: 26)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.12))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("从历史记录中移除该内容")
                    
                    Text(item.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(item.isPinned ? Color.blue.opacity(0.3) : Color.primary.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity))
    }
}

#Preview {
    ContentView()
}
