import SwiftUI

struct ToolboxView: View {
    @State private var selectedTool: ToolType? = nil

    var body: some View {
        if let tool = selectedTool {
            toolDetailView(for: tool)
        } else {
            toolList
        }
    }

    // MARK: - 工具列表

    private var toolList: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("工具箱")
                        .font(.headline.weight(.semibold))
                    Text("共 \(ToolItem.allTools.count) 个工具")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()
            }
            .padding(14)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 8)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(ToolItem.allTools) { tool in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTool = tool.id
                            }
                        }) {
                            HStack(spacing: 14) {
                                Image(systemName: tool.icon)
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(.blue)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color.blue.opacity(0.1))
                                    )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(tool.name)
                                        .font(.body.weight(.medium))
                                        .foregroundColor(.primary)
                                    Text(tool.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.95))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - 工具详情路由

    @ViewBuilder
    private func toolDetailView(for tool: ToolType) -> some View {
        switch tool {
        case .timestampConverter:
            TimestampConverterView {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTool = nil
                }
            }
        }
    }
}
