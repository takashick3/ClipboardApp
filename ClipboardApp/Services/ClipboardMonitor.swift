import AppKit
import Foundation

class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var isPasteInProgress = false

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setPasteInProgress(_ value: Bool) {
        isPasteInProgress = value
    }

    private func checkForChanges() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        if isPasteInProgress { return }

        guard let text = extractText(from: pasteboard), !text.isEmpty else { return }
        ClipboardStore.shared.add(text)
    }

    /// プレーンテキスト → RTF → RTFD の順で取得を試みる
    private func extractText(from pasteboard: NSPasteboard) -> String? {
        // 1. プレーンテキスト（最も一般的）
        if let text = pasteboard.string(forType: .string) {
            return text
        }

        // 2. RTF（Teams / Slack などリッチテキストアプリ）
        if let data = pasteboard.data(forType: .rtf),
           let attrStr = NSAttributedString(rtf: data, documentAttributes: nil) {
            let text = attrStr.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { return text }
        }

        // 3. RTFD（画像などの添付を含む RTF）
        if let data = pasteboard.data(forType: .rtfd),
           let attrStr = NSAttributedString(rtfd: data, documentAttributes: nil) {
            let text = attrStr.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { return text }
        }

        return nil
    }
}
