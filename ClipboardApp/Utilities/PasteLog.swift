import Foundation

/// 貼り付け診断ログ。設定画面（一般タブ）で ON にしたときだけ
/// `~/Library/Application Support/ClipboardApp/paste.log` に追記する（既定は OFF）。
///
/// 「たまに貼り付けできない」事象を事後に解析するためのもので、
/// 貼り付け内容そのものは記録しない（パスワード混入を避けるため文字数のみ）。
enum PasteLog {
    static let defaultsKey = "paste_logging"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }

    static let logFileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipboardApp", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("paste.log")
    }()

    /// 超えたら paste.log.1 へ退避（1世代のみ保持）
    private static let maxFileSize: UInt64 = 512 * 1024

    private static let queue = DispatchQueue(label: "com.takashick3.ClipboardApp.PasteLog", qos: .utility)

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    static func log(_ message: String) {
        DebugLog.log(message)
        guard isEnabled else { return }
        let line = "\(timestampFormatter.string(from: Date())) \(message)\n"
        queue.async {
            rotateIfNeeded()
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: logFileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: logFileURL)
            }
        }
    }

    private static func rotateIfNeeded() {
        let fm = FileManager.default
        guard let size = (try? fm.attributesOfItem(atPath: logFileURL.path))?[.size] as? UInt64,
              size > maxFileSize else { return }
        let backup = logFileURL.deletingLastPathComponent().appendingPathComponent("paste.log.1")
        try? fm.removeItem(at: backup)
        try? fm.moveItem(at: logFileURL, to: backup)
    }
}
