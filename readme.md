# Paste

`Paste` 是一个 macOS 状态栏剪贴板工具，支持剪贴板历史、快速粘贴弹窗、截图和简单工具箱。

这份仓库当前可以直接产出可分发的未签名安装包，不依赖 App Store。

## 当前可分发文件

- 安装包：`dist/Paste-macOS-unsigned.zip`
- SHA-256：`bdaf4f15d95eadce96acbe1f7191d68ed930ca8710c69e08510805cc7f47b846`

说明：

- 这是未签名、未 notarize 的 macOS 安装包
- 其他用户可以下载安装，但首次打开时需要手动放行

## 安装

1. 下载 `Paste-macOS-unsigned.zip`
2. 双击解压，得到 `Paste.app`
3. 将 `Paste.app` 拖入“应用程序”
4. 首次打开时，如果 macOS 提示应用无法验证：
   在 Finder 中右键 `Paste.app`，选择“打开”
5. 如果仍被拦截：
   打开“系统设置” -> “隐私与安全性”
   在底部找到被阻止的 `Paste.app`
   点击“仍要打开”

如果用户更熟悉终端，也可以执行：

```bash
xattr -dr com.apple.quarantine /Applications/Paste.app
```

## 首次使用

启动后，应用会常驻在状态栏。

第一次使用时，建议按下面顺序完成授权：

1. 打开 `Paste.app`
2. 给“辅助功能”权限
   位置：“系统设置” -> “隐私与安全性” -> “辅助功能”
3. 如果要使用截图功能，再给“屏幕录制”权限
   位置：“系统设置” -> “隐私与安全性” -> “屏幕与系统音频录制”

没有这些权限时，某些功能可以打开，但定位、粘贴或截图会受限。

## 功能

- 剪贴板历史：记录最近复制的文本和图片
- Quick Paste：快捷键呼出最近 10 条剪贴板内容
- 截图：框选截图并写入剪贴板
- 工具箱：内置一些轻量开发工具
- 状态栏常驻：从菜单栏直接访问

## 快捷键

| 功能 | 快捷键 |
| --- | --- |
| 打开主界面 | `Command + Shift + P` |
| 打开 Quick Paste | `Command + Shift + V` |
| 截图 | `Command + Shift + S` |
| 关闭 Quick Paste | `Esc` |
| 上下切换条目 | `↑` / `↓` |
| 确认选择 | `Enter` |
| 快速选择第 1-9 条 | `1` 到 `9` |

## Quick Paste 使用方式

1. 在任意输入框中先复制一些内容
2. 按 `Command + Shift + V`
3. 屏幕上会出现一个小弹窗，展示最近的剪贴板历史
4. 你可以：
   用鼠标悬停或点击选择
   或用键盘上下键切换、回车确认
   或直接按数字 `1-9` 选择对应项

## 已知限制

- 当前分发包是未签名版本，首次打开需要手动放行
- 没有 Apple Developer Program 账号时，无法做 App Store 分发和 notarization
- 某些网页、浏览器或复杂输入框中的定位行为依赖系统权限和宿主应用实现，效果可能有差异
- 当前环境里 `dmg` 生成失败，所以默认提供 `zip` 安装包

## 本地构建

```bash
xcodebuild -project Paste.xcodeproj -scheme Paste -configuration Release -derivedDataPath .derivedData build
```

构建完成后，应用产物在：

```bash
.derivedData/Build/Products/Release/Paste.app
```

打包 zip：

```bash
ditto -c -k --sequesterRsrc --keepParent .derivedData/Build/Products/Release/Paste.app dist/Paste-macOS-unsigned.zip
```

## 预览

![主界面](/Users/huskyui/github-repo/paste/_image/2.png)

![状态栏与设置](/Users/huskyui/github-repo/paste/_image/3.png)
