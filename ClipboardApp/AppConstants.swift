import Foundation

enum AppConstants {
    /// Info.plist の CFBundleShortVersionString から自動取得。バージョンはここではなく project.yml / Info.plist で管理する
    static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    /// 検証中ビルドの目印。リリース時は空文字に戻す
    static let testTag = ""
    static let versionLabel = "Ver\(version)" + (testTag.isEmpty ? "" : " (\(testTag))")
}
