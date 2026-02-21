# Polish for macOS

Polish 是一个 macOS 文本润色工具：选中文本后按 `⌥⌘P`，先确认编辑，再一键生成简化版、优化版和 `Commit Message`。

- 官网（落地页）：[https://zjy4fun.github.io/polish-macos/](https://zjy4fun.github.io/polish-macos/)
- 下载地址（GitHub Releases）：[https://github.com/zjy4fun/polish-macos/releases](https://github.com/zjy4fun/polish-macos/releases)
- 仓库地址：[https://github.com/zjy4fun/polish-macos](https://github.com/zjy4fun/polish-macos)

## 功能亮点

- 全局快捷键：`⌥⌘P`
- 读取当前选中文本（非剪贴板）
- 先确认编辑，再开始润色
- 输出三段结果：简化版本、优化版本、Commit Message
- 同文本 + 同 Provider 配置自动命中缓存
- 菜单栏图标可恢复最近一次结果窗口
- 默认 Provider：Codex CLI（可切 OpenAI / Claude）
- 全新品牌图标（应用图标 + 菜单栏图标）

## 快速开始

> 需要 macOS 13+ 和 Xcode 15+

```bash
cd macos
swift build
swift run PolishMac
```

## 使用流程

1. 启动应用。
2. 在任意应用里选中文本。
3. 按 `⌥⌘P` 唤起确认窗口。
4. 编辑原文后点击“开始润色”。
5. 查看并复制需要的结果。

## Provider 配置

### Codex CLI（默认）

- 命令模板默认值：`codex exec --skip-git-repo-check {{prompt}}`
- 需本机可直接执行 `codex`

### OpenAI API

- 需要 `API Key`
- Endpoint 默认：`https://api.openai.com/v1/chat/completions`

### Claude Code CLI

- 命令模板默认值：`claude -p {{prompt}}`
- 需本机可直接执行 `claude`

`{{prompt}}` 会自动替换为结构化提示词 + 已确认文本。

## 落地页与部署

- 落地页源码：`/docs/index.html`
- 图标资源：`/docs/assets/polish-brand-icon.svg`
- GitHub Pages 工作流：`/.github/workflows/pages.yml`

默认会在 `main` 分支 `docs/**` 变更时自动部署页面。

## 注意事项

- 首次读取选中文本时，系统可能弹出“辅助功能”授权提示。
- 如果快捷键与其他应用冲突，可在代码中调整。
