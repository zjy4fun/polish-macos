# Polish for macOS

一个使用 Swift 实现的 macOS 文本润色应用：

- 全局快捷键 `⌘P` 触发润色
- 自动读取当前 App 的**选中文本**（需辅助功能权限）
- 调用 OpenAI Chat Completions API 同时生成多种输出
- 浮窗同时展示：原文、简化版本、优化表述版本、commit message，并可一键替换
- **隐私安全**：API Key 仅存储在本地（UserDefaults）

## 技术实现

- SwiftUI + AppKit（状态栏 + 浮窗）
- Carbon HotKey（全局快捷键注册）
- Accessibility API（读取/替换选中文本）
- URLSession（调用 OpenAI API）

## 快速开始

> 需要 macOS 13+ 与 Xcode 15+

```bash
cd macos
swift build
swift run PolishMac
```

首次运行后，请按提示在系统设置中授予辅助功能权限：

- `系统设置 -> 隐私与安全性 -> 辅助功能`

## 使用说明

1. 启动应用（状态栏会出现 `Polish`）
2. 在任意可编辑文本区域中选中文字
3. 按 `⌘P`
4. 在浮窗中查看润色结果，点击“替换选中文本”

## 设置项

在状态栏菜单打开“设置”可以配置：

- OpenAI API Key
- API Endpoint（默认 `https://api.openai.com/v1/chat/completions`）

## 注意事项

- `⌘P` 在部分应用中是打印快捷键，若冲突可在代码中调整。
- 仅对支持辅助功能文本接口的应用有效。
- API Key 保存在本地 `UserDefaults`。
