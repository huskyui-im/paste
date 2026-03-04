import SwiftUI
import AppKit

struct TimestampConverterView: View {
    let onBack: () -> Void

    @State private var input = ""
    @State private var result = ""
    @State private var copied = false

    // 正向：时间戳 → 日期；反向：日期 → 时间戳
    @State private var isReverse = false
    // true = 毫秒，false = 秒
    @State private var useMilliseconds = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.timeZone = TimeZone.current
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 顶部导航
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("返回")
                    }
                    .font(.subheadline.weight(.medium))
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                Text("时间戳转换")
                    .font(.headline.weight(.semibold))

                Spacer()

                // 占位，保持标题居中
                Text("返回").opacity(0)
                    .font(.subheadline.weight(.medium))
            }

            Divider()

            // 模式切换
            Picker("", selection: $isReverse) {
                Text("时间戳 → 日期").tag(false)
                Text("日期 → 时间戳").tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: isReverse) {
                input = ""
                result = ""
                copied = false
            }

            // 秒/毫秒切换
            HStack(spacing: 8) {
                Text("单位:")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                Picker("", selection: $useMilliseconds) {
                    Text("秒 (s)").tag(false)
                    Text("毫秒 (ms)").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .onChange(of: useMilliseconds) {
                    if !input.isEmpty {
                        convert(input)
                    }
                }
            }

            // 输入
            VStack(alignment: .leading, spacing: 6) {
                Text(isReverse ? "输入日期" : "输入时间戳")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)

                TextField(
                    isReverse ? "例如: 2024-03-05 00:00:00" : (useMilliseconds ? "例如: 1709568000000" : "例如: 1709568000"),
                    text: $input
                )
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(.body, design: .monospaced))
                .onChange(of: input) {
                    convert(input)
                }
            }

            // 结果
            if !result.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("转换结果")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)

                    HStack {
                        Text(result)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.green.opacity(0.08))
                            )

                        Button(action: copyResult) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(copied ? .green : .blue)
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(copied ? Color.green.opacity(0.12) : Color.blue.opacity(0.12))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("复制结果")
                    }
                }
            }

            Spacer()
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 8)
    }

    private func convert(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            result = ""
            return
        }
        copied = false

        if isReverse {
            // 日期 → 时间戳
            if let date = Self.dateFormatter.date(from: trimmed) {
                if useMilliseconds {
                    let ts = Int(date.timeIntervalSince1970 * 1000)
                    result = "\(ts)"
                } else {
                    let ts = Int(date.timeIntervalSince1970)
                    result = "\(ts)"
                }
            } else {
                result = "格式错误，请输入 yyyy-MM-dd HH:mm:ss"
            }
        } else {
            // 时间戳 → 日期
            guard let ts = Double(trimmed) else {
                result = "请输入有效的数字时间戳"
                return
            }
            let interval: TimeInterval = useMilliseconds ? ts / 1000.0 : ts
            let date = Date(timeIntervalSince1970: interval)
            result = Self.dateFormatter.string(from: date)
        }
    }

    private func copyResult() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(result, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }
}
