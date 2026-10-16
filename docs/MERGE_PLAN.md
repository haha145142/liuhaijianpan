# MERGE_PLAN

目标：将 JevJarvis-liuhai-IOS（作为 UI/交互基线）与 goutou-keyboard-ios（作为 AI/回复能力实现）合并到本仓库的 merge/goutou-integration 分支，并提供用于生成未签名 .ipa 的 GitHub Actions workflow。

主要原则：
- 保留 JevJarvis 的视觉与交互体验，最小改动 UI 结构。
- 将 goutou 的回复/Prompt/记忆模块重构为一个可插拔的 AIService 实现（GoutouAdapter）。
- 在 KeyboardViewController（UI 层）只依赖 AIService 协议，异步请求并回填回复。
- 把复杂面板（GoutouPanelView）作为“高级”功能，默认隐藏，主界面保留最简单的入口。
- 合并时保留原仓库的 LICENSE/NOTICE 信息（请在合并前检查许可条款）。

提交清单（此分支包含示例模板与 workflow）：
- docs/MERGE_PLAN.md （本文件）
- Sources/AI/AIService.swift （AIService 协议与上下文模型）
- Sources/AI/GoutouAdapter.swift （goutou -> AIService 的适配器模板）
- Keyboard/Sources/KeyboardAIIntegration.swift （对 KeyboardViewController 的非侵入性集成示例）
- .github/workflows/build-unsigned-ipa.yml （构建未签名 .ipa 的 workflow）
- docs/README_INTEGRATION.md （如何触发构建、下载 ipa 与本地签名说明）

关键修改点与操作步骤（概要）：
1. 把 goutou 仓库中以下文件迁移到 Sources/AI/ 并重命名/重构：
   - GoutouAIClient.swift -> GoutouAdapter.swift（去 UI 依赖，封装 HTTP/流式结果）
   - GoutouPrompt.swift -> 保留并作为 Prompt 模块
   - RecognizedChatContext/RecognizedChatAnalysis -> 用于替代 "只取最后一句" 的识别逻辑
   - Memory* 模块 -> 可选的记忆管理模块
   - 大词表（pinyin-words.tsv）按需合并到 Shared/Resources

2. 在 KeyboardViewController 中：
   - 找到触发“生成回复”的点（现有逻辑或按钮），替换为调用 AIService.shared.requestReply(context:completion:)
   - 在回调中把回复展示到候选栏或直接插入到文本输入
   - 增加最小的错误/超时处理与加载状态指示

3. 简化 UI：
   - 将 GoutouPanelView 的复杂操作迁移到一个“设置/高级”页面（非键盘主视图），默认隐藏
   - 主界面保留：回复按钮、记忆开关、设置入口

4. Entitlements / App Groups：
   - 如果需要宿主 App 与扩展共享数据（如记忆/配置），请在 Xcode 工程中启用 App Groups 并在 entitlements 文件中配置相同 group。注意：这些能力会影响正式签名，但不会阻止我们生成未签名 ipa。

5. CI / 构建（workflow 已加入）：
   - workflow 使用 macOS runner 构建 Xcode 工程并生成未签名 ipa，然后把 ipa 上传为 artifact。
   - 请在仓库 Settings 中允许 Actions 运行 macOS 构建。
   - 如果项目使用 CocoaPods，workflow 会尝试运行 pod install（仅当 Podfile 存在时）。

6. API Key 与 Secrets：
   - 不要把真实 API Key 提交到仓库。建议在仓库 Secrets 中添加：GOUTOU_API_KEY（或你偏好的名字），workflow 与运行时读取该 Secret。

7. 许可合规：
   - 合并时请保留原项目的 LICENSE/NOTICE 文件内容（本分支会在 README 中引用原项目许可）。

常见调试点：
- scheme 名称与 xcodeproj 路径：在 workflow 中默认使用 `JevJarvis.xcodeproj` 与 scheme `JevJarvis`。若工程有不同 scheme，请修改 .github/workflows/build-unsigned-ipa.yml 中的变量。
- 第三方依赖：CocoaPods/SwiftPM/Carthage 差异会导致构建失败，按需要在 workflow 中调整依赖安装步骤。

下一步：
- 请在仓库 Settings 中开启 Actions（macOS runner 权限）。
- 如果你愿意，我可以把 goutou 的核心文件（不含 UI）迁入 Sources/AI 并提交一个初步的集成实现，供你在设备上或 simulator 上测试。