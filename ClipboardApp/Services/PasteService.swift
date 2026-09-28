import AppKit
import CoreGraphics
import ApplicationServices
import Carbon

class PasteService {
    static let shared = PasteService()

    private init() {}

    /// ポップアップを開く直前に捕捉した、貼り付け先の要素とそのセキュア判定。
    /// ポップアップにフォーカスが移った後でも元のフィールドへ書き込めるようにする。
    private var capturedElement: AXUIElement?
    private var capturedIsSecure = false
    /// 貼り付け先が Spotlight など「アプリをアクティブ化せずに戻る」相手のとき true。
    /// ポップアップ表示・終了時に自アプリ／元アプリのアクティブ化を行わず、
    /// ⌘V が確実に届く保証もないため、クリップボードを復元せず手動 ⌘V でリカバリー可能にする。
    private(set) var capturedKeepsFrontAppActive = false

    /// 捕捉した要素を所有するプロセス。Spotlight のように「最前面アプリとは別プロセスが
    /// 入力欄を出している」場合、NSWorkspace の frontmostApplication では検出できないため、
    /// AX 要素の pid から求める。
    private(set) var capturedOwnerApp: NSRunningApplication?

    /// 別アプリがアクティブになると閉じてしまう入力欄の所有プロセス（bundle ID）。
    /// macOS 26 以降の Spotlight は Siri プロセス（com.apple.campo）が入力欄を持つ。
    private static let fragileOwnerApps: Set<String> = ["com.apple.Spotlight", "com.apple.campo"]

    /// ポップアップを開く「直前」に呼び出すこと。
    /// このタイミングならまだ元のフィールド（パスワード欄など）にフォーカスがあるため、
    /// 正しくセキュア判定でき、要素参照も保持できる。
    /// 戻り値は「元アプリをアクティブなままにすべきか」（`capturedKeepsFrontAppActive` と同じ）。
    @discardableResult
    func captureTarget() -> Bool {
        let front = NSWorkspace.shared.frontmostApplication
        let app = frontmostAppDescription()
        guard let element = copyFocusedElement() else {
            capturedElement = nil
            capturedIsSecure = false
            capturedOwnerApp = nil
            capturedKeepsFrontAppActive = false
            PasteLog.log("[Capture] app=\(app) フォーカス要素なし")
            return false
        }
        capturedElement = element
        capturedIsSecure = isSecureTextField(element)

        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        let owner = NSRunningApplication(processIdentifier: pid)
        capturedOwnerApp = owner

        // 所有プロセスが最前面アプリと異なる（Spotlight 等のフローティング入力欄）か、
        // 既知の「アクティブ化すると閉じる」プロセスなら、元アプリをアクティブなままにする。
        let ownerDiffers = owner != nil && front != nil && owner!.processIdentifier != front!.processIdentifier
        let ownerIsFragile = Self.fragileOwnerApps.contains(owner?.bundleIdentifier ?? "")
        capturedKeepsFrontAppActive = ownerDiffers || ownerIsFragile

        let ownerDesc = owner.map { "\($0.localizedName ?? "?")(\($0.bundleIdentifier ?? "?"))" } ?? "pid:\(pid)"
        PasteLog.log("[Capture] app=\(app) owner=\(ownerDesc) role=\(roleDescription(element)) "
                     + "secure=\(capturedIsSecure) keepsFront=\(capturedKeepsFrontAppActive)")
        return capturedKeepsFrontAppActive
    }

    private func roleDescription(_ element: AXUIElement) -> String {
        var role: CFTypeRef?
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
        return "\(role as? String ?? "?")/\(subrole as? String ?? "-")"
    }

    func paste(text: String, monitor: ClipboardMonitor) {
        let wasSecure = capturedIsSecure
        let target = capturedElement
        let keepsFront = capturedKeepsFrontAppActive
        clearCapture()

        PasteLog.log("[Paste] 開始 len=\(text.count) secure=\(wasSecure) "
                     + "targetCaptured=\(target != nil) keepsFront=\(keepsFront) "
                     + "secureEventInput=\(IsSecureEventInputEnabled()) "
                     + "axTrusted=\(AXIsProcessTrusted())")

        monitor.setPasteInProgress(true)

        // ① セキュア欄: 捕捉済みの要素へ AX 経由で直接書き込む。
        //    キーイベントもクリップボードも使わないため、フォーカスが移っていても、
        //    Secure Event Input が有効でも書き込める（要素が許可していれば）。
        if wasSecure, let target, setValueViaAccessibility(target, text: text) {
            PasteLog.log("[Paste] → ① AX 直接書き込み成功（捕捉済みセキュア欄）")
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
            PasteLog.log("[Paste] → ② セキュア欄だが AX 不可（⌘V／失敗時は手動）")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.sendCmdV()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    monitor.setPasteInProgress(false)
                    ToastWindowController.shared.show(message: "貼り付かない場合は Cmd+V")
                }
            }
        } else if target == nil || keepsFront {
            // ④ 貼り付け先が AX で見えないアプリ（Electron 等）、または Spotlight のように
            //    アプリをアクティブ化せずに戻る相手。ポップアップがフォーカスを奪った時点で
            //    入力欄が閉じるなど、⌘V が空振りする可能性がある。失敗に備えて
            //    クリップボードは復元せず選択テキストを残し、手動 ⌘V でリカバリーできるようにする。
            PasteLog.log("[Paste] → ④ capture不可または keepsFront（⌘V／復元なし・失敗時は手動）")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.sendCmdV()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    monitor.setPasteInProgress(false)
                    ToastWindowController.shared.show(message: "貼り付かない場合は Cmd+V")
                }
            }
        } else {
            // ③ 通常フィールド: ⌘V を送り、クリップボードを元に戻す。
            PasteLog.log("[Paste] → ③ 通常フィールド（⌘V）")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.sendCmdV()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    monitor.setPasteInProgress(false)
                    self.restoreClipboard(previousText)
                    PasteLog.log("[Paste] 完了（クリップボード復元）")
                }
            }
        }
    }

    /// 現在の最前面アプリを「アプリ名(bundle ID)」形式で返す。ログ用。
    private func frontmostAppDescription() -> String {
        guard let app = NSWorkspace.shared.frontmostApplication else { return "不明" }
        return "\(app.localizedName ?? "?")(\(app.bundleIdentifier ?? "?"))"
    }

    private func clearCapture() {
        capturedElement = nil
        capturedIsSecure = false
        capturedOwnerApp = nil
        capturedKeepsFrontAppActive = false
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
        // 送出直前の最前面アプリを記録する。Capture 時と食い違っていれば
        // 「フォーカス復帰が間に合っていない」ことが失敗原因だと分かる。
        PasteLog.log("[Paste] ⌘V送出 front=\(frontmostAppDescription()) "
                     + "secureEventInput=\(IsSecureEventInputEnabled())")
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
