//
//  ClipboardItem.swift
//  Paste
//
//  Created by 王鹏 on 2025/11/2.
//

import Foundation


struct ClipboardItem: Identifiable,Codable,Equatable {
    let id: UUID
    let content: String
    let timestamp: Date
    var isPinned: Bool
    
    init(content:String,isPinned: Bool = false){
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.isPinned = isPinned
    }
}

