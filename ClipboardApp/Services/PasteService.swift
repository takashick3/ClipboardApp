import AppKit
import CoreGraphics
import ApplicationServices

class PasteService {
    static let shared = PasteService()

    private init() {}

    /// ポップアップを開く直前に捕捉した、貼り付け先の要素とそのセキュア判定。
    /// ポップアップにフォーカスが移った後でも元のフィールドへ書き込めるようにする。
    private var capturedElement: AXUIElement?
    private var capturedIsSecure = false

    /// ポップアップを開く「直前」に呼び出すこと。
    /// このタイミングならまだ元のフィールド（パスワード欄など）にフォーカスがあるため、
    /// 正しくセキュア判定でき、要素参照も保持できる。
    func captureTarget() {
        guard let element = copyFocusedElement() else {
            capturedElement = nil
            capturedIsSecure = false
            DebugLog.log("[Capture] フォーカス要素なし")
            return
        }
        capturedElement = element
        capturedIsSecure = isSecureTextField(element)
        DebugLog.log("[Capture] secure=\(capturedIsSecure)")
    }

    func paste(text: String, monitor: ClipboardMonitor) {
        let wasSecure = capturedIsSecure
        let target = capturedElement
        clearCapture()

        monitor.setPasteInProgress(true)

        // ① セキュア欄: 捕捉済みの要素へ AX 経由で直接書き込む。
        //    キーイベントもクリップボードも使わないため、フォーカスが移っていても、
        //    Secure Event Input が有効でも書き込める（要素が許可していれば）。
        if wasSecure, let target, setValueViaAccessibility(target, text: text) {
            DebugLog.log("[Paste] → ① AX 直接書き込み成功（捕捉済みセキュア欄）")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                monitor.setPasteInProgress(false)
            }
            return
        }

        // クリップボードへ載せて ⌘V を送る共通処理。
        let previousText = NSPasteboard.general.string(forType: .string)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        if wasSecure {
            // ② AX 書き込み不可のセキュア欄。⌘V を試しつつ、
            //    失敗に備えてクリップボードは復元せず手動 ⌘V 用に残す。
            DebugLog.log("[Paste] → ② セキュア欄だが AX 不可（⌘V／失敗時は手動）")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.sendCmdV()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    monitor.setPasteInProgress(false)
                    ToastWindowController.shared.show(message: "貼り付かない場合は Cmd+V")
                }
            }
        } else {
            // ③ 通常フィールド: ⌘V を送り、クリップボードを元に戻す。
            DebugLog.log("[Paste] → ③ 通常フィールド（⌘V）")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.sendCmdV()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    monitor.setPasteInProgress(false)
                    self.restoreClipboard(previousText)
                }
            }
        }
    }

    private func clearCapture() {
        capturedElement = nil
        capturedIsSecure = false
    }

    private func restoreClipboard(_ previousText: String?) {
        guard let prev = previousText else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prev, forType: .string)
    }

    /// 現在フォーカスされている UI 要素を取得する。
    private func copyFocusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide,
                                            kAXFocusedUIElementAttribute as CFString,
                                            &focusedRef) == .success,
              let focusedRef else { return nil }

        return (focusedRef as! AXUIElement)  // AXUIElement は CFTypeRef と toll-free bridge
    }

    /// 要素がセキュアテキストフィールド（パスワード欄など）か判定する。
    private func isSecureTextField(_ element: AXUIElement) -> Bool {
        var subroleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element,
                                            kAXSubroleAttribute as CFString,
                                            &subroleRef) == .success,
              let subrole = subroleRef as? String else { return false }

        return subrole == "AXSecureTextField"
    }

    /// Accessibility 経由でフィールドの値に直接テキストを書き込む。
    /// キーイベントを使わないため Secure Event Input の影響を受けないが、
    /// フィールド側が書き込みを許可していない場合は失敗する。
    private func setValueViaAccessibility(_ element: AXUIElement, text: String) -> Bool {
        var settable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(element,
                                             kAXValueAttribute as CFString,
                                             &settable) == .success,
              settable.boolValue else { return false }

        return AXUIElementSetAttributeValue(element,
                                            kAXValueAttribute as CFString,
                                            text as CFString) == .success
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
