import SwiftUI

struct ContentView: View {
    @StateObject private var clipboardService = ClipboardService()
    @State private var searchText = ""
    @State private var showOnlyPinned = false
    
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
        VStack(spacing: 0) {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索剪切板历史...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
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
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // 工具栏
            HStack {
                Text("剪切板历史 (\(filteredItems.count))")
                    .font(.headline)
                
                Spacer()
                
                Toggle("仅显示置顶", isOn: $showOnlyPinned)
                    .toggleStyle(CheckboxToggleStyle())
                
                Button("清空") {
                    clipboardService.clearHistory()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // 历史记录列表
            if filteredItems.isEmpty {
                VStack {
                    Image(systemName: "clipboard")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("暂无复制历史")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredItems) { item in
                    ClipboardItemRow(
                        item: item,
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
                .listStyle(PlainListStyle())
            }
            
            // 底部状态栏
            HStack {
                Text("当前内容: \(clipboardService.currentClipboardContent.prefix(30))...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                Button("退出") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 500, height: 600)
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 置顶/复制按钮区域
            VStack(spacing: 8) {
                Button(action: onPin) {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                        .foregroundColor(item.isPinned ? .blue : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // 内容区域
            VStack(alignment: .leading, spacing: 4) {
                Text(item.content)
                    .textSelection(.enabled)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    Text(item.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if item.isPinned {
                        Text("已置顶")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ContentView()
}
