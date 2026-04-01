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
    let imageData: Data?
    let timestamp: Date
    var isPinned: Bool

    var isImage: Bool { imageData != nil }

    init(content:String,isPinned: Bool = false){
        self.id = UUID()
        self.content = content
        self.imageData = nil
        self.timestamp = Date()
        self.isPinned = isPinned
    }

    init(imageData: Data, isPinned: Bool = false) {
        self.id = UUID()
        self.content = "[图片]"
        self.imageData = imageData
        self.timestamp = Date()
        self.isPinned = isPinned
    }

    init(id: UUID, content: String, imageData: Data?, timestamp: Date, isPinned: Bool) {
        self.id = id
        self.content = content
        self.imageData = imageData
        self.timestamp = timestamp
        self.isPinned = isPinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
    }
}

struct PersistedClipboardItem: Codable {
    let id: UUID
    let content: String
    let timestamp: Date
    let isPinned: Bool

    init(item: ClipboardItem) {
        self.id = item.id
        self.content = item.content
        self.timestamp = item.timestamp
        self.isPinned = item.isPinned
    }

    var clipboardItem: ClipboardItem {
        ClipboardItem(id: id, content: content, imageData: nil, timestamp: timestamp, isPinned: isPinned)
    }
}
