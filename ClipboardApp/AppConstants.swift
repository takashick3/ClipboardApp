import Foundation

enum AppConstants {
    /// Info.plist の CFBundleShortVersionString から自動取得。バージョンはここではなく project.yml / Info.plist で管理する
    static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    static let versionLabel = "Ver\(version)"
}
