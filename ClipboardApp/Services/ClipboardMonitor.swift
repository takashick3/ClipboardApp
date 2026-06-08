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

    /// プレーンテキスト → RTF → RTFD → ファイルパス → URL → HTML の順で取得を試みる
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

        // 4. ファイルパス（Finder のクイックアクション等）
        //    複数選択時は改行区切りで結合する
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            return urls.map(\.path).joined(separator: "\n")
        }

        // 5. Web URL（メール・メモアプリ等でリンクのみコピーした場合）
        if let urlString = pasteboard.string(forType: .URL) {
            return urlString
        }

        // 6. HTML（Notion / Google Docs 等で .string が存在しない場合）
        if let data = pasteboard.data(forType: .html),
           let html = String(data: data, encoding: .utf8) {
            let text = html
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { return text }
        }

        return nil
    }
}
