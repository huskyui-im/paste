//
//  ClipboardService.swift
//  Paste
//
//  Created by 王鹏 on 2025/11/2.
//

import AppKit
import Combine

class ClipboardService: ObservableObject{
    @Published var clipboardHistory: [ClipboardItem] = []
    @Published var currentClipboardContent: String = ""
    
    
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var timer: Timer?
    private let maxHistoryCount = 10
    
    init(){
        loadHistory()
        startMonitoring()
    }
    
    func startMonitoring() {
        // 每0.5秒检查一次剪切板变化
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        
        // 检查剪切板是否有变化
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        
        // 获取文本内容
        if let content = pasteboard.string(forType: .string), !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            
            // 避免重复记录相同内容
            if !clipboardHistory.contains(where: { $0.content == content }) {
                let newItem = ClipboardItem(content: content)
                
                DispatchQueue.main.async {
                    self.clipboardHistory.insert(newItem, at: 0)
                    self.currentClipboardContent = content
                    self.trimHistory()
                    self.saveHistory()
                }
            }
        }
    }
    
    private func trimHistory() {
            if clipboardHistory.count > maxHistoryCount {
                clipboardHistory = Array(clipboardHistory.prefix(maxHistoryCount))
            }
    }
    
    
    // 数据持久化
    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(clipboardHistory)
            UserDefaults.standard.set(encoded, forKey: "clipboardHistory")
        } catch {
            print("保存剪切板历史失败: \(error)")
        }
    }
    
    
    
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: "clipboardHistory") else { return }
        
        do {
            let decoder = JSONDecoder()
            clipboardHistory = try decoder.decode([ClipboardItem].self, from: data)
        } catch {
            print("加载剪切板历史失败: \(error)")
        }
    }
    
    func stopMonitoring() {
            timer?.invalidate()
            timer = nil
    }
    
    func copyToClipboard(_ content: String) {
         let pasteboard = NSPasteboard.general
         pasteboard.clearContents()
         pasteboard.setString(content, forType: .string)
         lastChangeCount = pasteboard.changeCount
     }
    
    func deleteItem(_ item: ClipboardItem) {
            clipboardHistory.removeAll { $0.id == item.id }
            saveHistory()
    }
    
    func togglePin(_ item: ClipboardItem) {
            if let index = clipboardHistory.firstIndex(where: { $0.id == item.id }) {
                clipboardHistory[index].isPinned.toggle()
                saveHistory()
            }
    }
    
    func clearHistory() {
           clipboardHistory.removeAll()
           saveHistory()
       }

    
    
    
    
}


