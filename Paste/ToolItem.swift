import Foundation

enum ToolType: String, CaseIterable, Identifiable {
    case timestampConverter
    // case jsonFormatter  // coming soon

    var id: String { rawValue }
}

struct ToolItem: Identifiable {
    let id: ToolType
    let name: String
    let icon: String
    let description: String

    static let allTools: [ToolItem] = [
        ToolItem(
            id: .timestampConverter,
            name: "时间戳转换",
            icon: "clock",
            description: "输入时间戳，转换为标准时间格式"
        ),
    ]
}
