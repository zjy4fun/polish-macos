# Polish for macOS

一个使用 Swift 实现的 macOS 文本润色应用：

- 全局快捷键 `⌘P` 触发润色
- 直接读取**剪切板文本**（无需读取选中文本）
- 调用 OpenAI Chat Completions API 同时生成多种输出
- 浮窗同时展示：原文、简化版本、优化表述版本、commit message
- 支持一键复制任意版本到剪切板
- **隐私安全**：API Key 仅存储在本地（UserDefaults）

## 技术实现

- SwiftUI + AppKit（状态栏 + 浮窗）
- Carbon HotKey（全局快捷键注册）
- NSPasteboard（读取/写入剪切板）
- URLSession（调用 OpenAI API）

## 快速开始

> 需要 macOS 13+ 与 Xcode 15+

```bash
cd macos
swift build
swift run PolishMac
```

## 使用说明

1. 启动应用（状态栏会出现 `Polish`）
2. 在任意应用中先复制文本（`⌘C`）
3. 按 `⌘P`
4. 在浮窗中查看各版本结果，并按需复制

## 设置项

在状态栏菜单打开“设置”可以配置：

- OpenAI API Key
- API Endpoint（默认 `https://api.openai.com/v1/chat/completions`）

## 注意事项

- `⌘P` 在部分应用中是打印快捷键，若冲突可在代码中调整。
- API Key 保存在本地 `UserDefaults`。
