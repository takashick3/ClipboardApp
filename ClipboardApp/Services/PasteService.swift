import AppKit
import CoreGraphics
import ApplicationServices

class PasteService {
    static let shared = PasteService()

    private init() {}

    func paste(text: String, monitor: ClipboardMonitor) {
        let previousText = NSPasteboard.general.string(forType: .string)
        let isSecure = isFocusedElementSecure()

        monitor.setPasteInProgress(true)

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        if isSecure {
            // パスワード欄などセキュアな入力フィールドでは macOS が CGEvent をブロックする。
            // クリップボードにセットしたまま残し、ユーザーが手動で Cmd+V で貼り付けられる状態にする。
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                monitor.setPasteInProgress(false)
                // クリップボードは意図的に復元しない
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.sendCmdV()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    monitor.setPasteInProgress(false)
                    if let prev = previousText {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(prev, forType: .string)
                    }
                }
            }
        }
    }

    /// フォーカス中の UI 要素がセキュアテキストフィールド（パスワード欄など）か判定する。
    /// セキュア入力モードでは CGEvent による Cmd+V がブロックされるため、
    /// 自動貼り付けをスキップしてクリップボードを残す判断に使う。
    private func isFocusedElementSecure() -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide,
                                            kAXFocusedUIElementAttribute as CFString,
                                            &focusedRef) == .success,
              let focusedRef else { return false }

        let focusedElement = focusedRef as! AXUIElement  // AXUIElement は CFTypeRef と toll-free bridge
        var subroleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedElement,
                                            kAXSubroleAttribute as CFString,
                                            &subroleRef) == .success,
              let subrole = subroleRef as? String else { return false }

        return subrole == "AXSecureTextField"
    }

    private func sendCmdV() {
        let src = CGEventSource(stateID: .hidSystemState)
        let vKeyCode: CGKeyCode = 0x09

        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
