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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
    }
}

