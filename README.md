# Polish for macOS

一个使用 Swift 实现的 macOS 文本润色应用：

- 全局快捷键 `⌥⌘P` 触发润色
- 直接读取**剪切板文本**（无需读取选中文本）
- 支持三种 Provider：
  - OpenAI API（可配置 API Endpoint）
  - 本地 Codex CLI
  - 本地 Claude Code CLI
- 首次启动提供引导设置界面
- 浮窗同时展示：原文、简化版本、优化表述版本、commit message
- 支持一键复制任意版本到剪切板

## 快速开始

> 需要 macOS 13+ 与 Xcode 15+

```bash
cd macos
swift build
swift run PolishMac
```

## 使用说明

1. 启动应用（状态栏会出现魔棒图标）
2. 首次在设置中完成引导：选择 Provider 并填写配置
3. 在任意应用中先复制文本（`⌘C`）
4. 按 `⌥⌘P`
5. 在浮窗中查看各版本结果，并按需复制

## Provider 配置

### 1) OpenAI API
- API Key
- API Endpoint（默认 `https://api.openai.com/v1/chat/completions`）

### 2) 本地 Codex CLI
- 命令模板：默认 `codex exec {{prompt}}`
- 要求本机可在终端直接执行 `codex`

### 3) 本地 Claude Code CLI
- 命令模板：默认 `claude -p {{prompt}}`
- 要求本机可在终端直接执行 `claude`

`{{prompt}}` 会被自动替换为结构化提示词和剪切板文本。

## 注意事项

- `⌥⌘P` 可避开大多数应用里 `⌘P` 的打印快捷键冲突。
- 使用本地 CLI 时，需确保对应命令已安装并可执行。
