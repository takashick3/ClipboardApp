import AppKit
import ApplicationServices

struct AccessibilityChecker {
    static func isAccessibilityEnabled() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    static func requestAccessibilityIfNeeded() {
        guard !isAccessibilityEnabled() else { return }

        // prompt: true でシステムに権限リクエストを発行し、
        // アプリを正しい identity で TCC データベースに登録させる
        let promptOptions: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        AXIsProcessTrustedWithOptions(promptOptions)

        let alert = NSAlert()
        alert.messageText = "アクセシビリティ権限が必要です"
        alert.informativeText = "ClipboardApp が自動ペースト機能を使用するには、アクセシビリティ権限が必要です。\n\n「システム設定」>「プライバシーとセキュリティ」>「アクセシビリティ」で ClipboardApp を許可してください。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "システム設定を開く")
        alert.addButton(withTitle: "終了")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
        NSApp.terminate(nil)
    }
}
