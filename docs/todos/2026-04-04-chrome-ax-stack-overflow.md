# Chrome AX 树遍历栈溢出

## 状态：已做临时修复

- 浏览器场景下已临时改为跳过所有 AX 查询，直接走安全降级，避免 Chrome / WebKit 类应用触发栈溢出 crash
- 当前取舍：浏览器里 Quick Paste 不再尝试跟随输入框光标，而是使用非 AX 的安全位置
- 后续如果要恢复“跟随光标”，需要基于更安全的浏览器特判方案单独实现

## 问题描述

在 Chrome 中按 `Cmd+Shift+V` 触发 Quick Paste 弹窗时，app crash，Xcode 进入 debug 模式。

- 报错：`Thread 1: EXC_BAD_ACCESS (code=2, address=0x16f42fff8)`
- 崩溃位置：`libsystem_pthread.dylib___chkstk_darwin`（栈溢出）
- 即使已跳过浏览器的 `findEditableInChildren` 子元素递归搜索，问题仍然存在

## 已排除

- 不是 `findEditableInChildren` 递归导致（已对浏览器跳过，crash 仍复现）
- 不是 `as!` 强制类型转换问题（CoreFoundation 类型 `as!` 不会失败）
- 不是辅助功能权限问题（已确认授权）

## 可能的原因

1. `nearestTextInputElement` 的 parent chain 遍历 — Chrome AX 元素的 parent 链可能形成循环引用或极深链路
2. `AXUIElementCopyAttributeValue` 访问 Chrome AX 元素时，系统内部递归过深
3. Chrome 进程的 AX 实现本身在被查询时触发了系统框架内的栈溢出
4. `focusedWindowComposerAnchor` 中获取 Chrome 窗口属性时触发问题

## 下一步排查

- [ ] 确认 crash 的完整调用栈（Xcode Debug Navigator → Thread 1 的 backtrace），定位具体是哪个 AX 调用触发
- [x] 尝试对浏览器完全跳过所有 AX 查询，直接使用 `screenCenter` fallback，验证是否解决
- [ ] 如果完全跳过 AX 可以解决，再逐步恢复：只调用 `AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute)` 获取窗口位置，不访问 focused element
- [ ] 考虑将 AX 查询移到后台线程（需注意 AX API 的线程安全性）

## 复现步骤

1. 从 Xcode Run Paste app
2. 打开 Chrome，点击地址栏
3. 按 `Cmd+Shift+V`
4. Xcode 自动进入 debug 模式，报 EXC_BAD_ACCESS

## 相关文件

- `Paste/QuickPasteWindow.swift` — `getAnchorRect()` 及相关 AX 查询方法
