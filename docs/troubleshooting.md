# Troubleshooting

## 清理旧版本 App

Xcode 每次编译会在 DerivedData 中生成新的 App 副本，导致系统权限列表中出现多个同名 App，无法确认哪个是当前版本。

### 查找所有副本

```bash
mdfind "kMDItemFSName == 'Paste.app'"
```

### 删除旧副本

```bash
# 删除系统默认 DerivedData 中的旧构建（路径中的 hash 值以实际输出为准）
rm -rf /Users/huskyui/Library/Developer/Xcode/DerivedData/Paste-*/

# 删除其他位置的旧副本（如有）
rm -rf ~/Downloads/Paste.app
```

> 注意：项目根目录下的 `.derivedData` 是当前使用的构建目录，不要删除。

## 重置辅助功能（Accessibility）权限

Quick Paste 弹窗的光标定位依赖 Accessibility API，需要在系统设置中授权。重新编译后 App 签名变化，可能需要重新授权。

### 重置权限

```bash
# 重置 Paste 的辅助功能权限
tccutil reset Accessibility huskyui.Paste

# 或重置所有 App 的辅助功能权限
tccutil reset Accessibility
```

### 重新授权

1. 从 Xcode 重新 Run
2. 按 `Cmd+Shift+V` 触发系统授权提示
3. 前往 **System Settings → Privacy & Security → Accessibility**，勾选 Paste
