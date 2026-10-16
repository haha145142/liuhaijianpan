import Foundation
import UIKit

// KeyboardAIIntegration.swift
// 非侵入性示例：在 JevJarvis 的 KeyboardViewController 中调用 AIService

extension KeyboardViewController {
    // 公开方法：外部 UI 触发调用，例如在某个按钮的 action 中调用
    @objc func triggerAIReplyAction() {
        // 获取当前识别或候选文本（示例: 假设 keyboard 有 currentComposedText 变量）
        let currentText = (self as AnyObject).value(forKey: "currentComposedText") as? String ?? ""
        generateAIReply(for: currentText)
    }

    // 调用 AI 生成回复的示例方法
    func generateAIReply(for inputText: String) {
        // 构建 history（示例：从本地会话/识别结果构建），这里简化为空历史
        let chatHistory: [ChatMessage] = [] // TODO: 用 RecognizedChatContext/RecognizedChatAnalysis 构建更完整上下文
        let ctx = ChatContext(inputText: inputText, history: chatHistory, locale: Locale.current.identifier)

        // 在 UI 上显示加载状态
        showLoadingIndicator(true)

        AIService.shared.requestReply(context: ctx) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.showLoadingIndicator(false)
                switch result {
                case .success(let reply):
                    // 将 reply 显示到候选区或直接插入到文本框
                    self.insertReplyIntoTextView(reply)
                case .failure(let err):
                    // 简短错误处理：在 UI 上提示并回退
                    self.showErrorToast("AI 回复失败：\(err)")
                }
            }
        }
    }

    // 示例 UI helper（需要在你的 KeyboardViewController 中实现或替换）
    func showLoadingIndicator(_ show: Bool) {
        // TODO: 在你的 UI 中显示/隐藏加载状态
    }

    func insertReplyIntoTextView(_ reply: String) {
        // TODO: 将回复插入到主候选区或通过 textDocumentProxy 插入
        // 例如：textDocumentProxy.insertText(reply)
        if let proxy = self.textDocumentProxy as? UITextDocumentProxy {
            proxy.insertText(reply)
        }
    }

    func showErrorToast(_ message: String) {
        // TODO: 在键盘上短暂显示错误信息（例如用 label）
    }
}
