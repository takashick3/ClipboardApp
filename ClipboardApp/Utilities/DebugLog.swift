import Foundation

/// デバッグログ。既定では出力せず、内部設定（UserDefaults）が有効なときだけ NSLog に出す。
///
/// 切り替え（ターミナルから）:
///   有効化: defaults write com.takashick3.ClipboardApp DebugLogging -bool true
///   無効化: defaults write com.takashick3.ClipboardApp DebugLogging -bool false
///   確認:   defaults read  com.takashick3.ClipboardApp DebugLogging
///
/// 変更後はアプリを再起動すると確実に反映される。
/// ログは `log stream --predicate 'process == "ClipboardApp"'` か、
/// バイナリ直接起動（/Applications/ClipboardApp.app/Contents/MacOS/ClipboardApp）で確認できる。
enum DebugLog {
    static let defaultsKey = "DebugLogging"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }

    /// message はクロージャで受け、無効時は文字列生成コストもかからないようにする。
    static func log(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        NSLog("🔍 \(message())")
    }
}
