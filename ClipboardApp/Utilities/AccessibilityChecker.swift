import AppKit
import ApplicationServices

struct AccessibilityChecker {
    static func isAccessibilityEnabled() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    static func requestAccessibilityIfNeeded() {
        guard !isAccessibilityEnabled() else { return }

        // Step1: まず説明ダイアログを出してからシステムダイアログを発火させる。
        // 逆順にすると「拒否」と「終了」が同時に出て混乱するため必ずこの順序を守る。
        let alert = NSAlert()
        alert.messageText = "アクセシビリティ権限が必要です"
        alert.informativeText = """
            ClipboardApp が自動ペースト機能を使用するには、アクセシビリティ権限が必要です。

            「続ける」を押すと確認ダイアログが表示されます。
            「システム設定を開く」→ ClipboardApp を ON にした後、
            アプリを再起動してください。
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "続ける")
        alert.addButton(withTitle: "終了")

        guard alert.runModal() == .alertFirstButtonReturn else {
            NSApp.terminate(nil)
            return
        }

        // Step2: ユーザーが「続ける」を押してからシステムダイアログを発火（TCC に正しく登録）
        let promptOptions: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        AXIsProcessTrustedWithOptions(promptOptions)
        NSApp.terminate(nil)
    }
}
