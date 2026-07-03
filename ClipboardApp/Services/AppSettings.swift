import Foundation
import ServiceManagement
import Combine

// MARK: - AppSettings

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let maxHistoryCount  = "max_history_count"
        static let popupWidth       = "popup_width"
        static let popupHeightRatio = "popup_height_ratio"
        static let fontSizeScale    = "font_size_scale"
    }

    // 履歴数
    @Published var maxHistoryCount: Int {
        didSet { UserDefaults.standard.set(maxHistoryCount, forKey: Keys.maxHistoryCount) }
    }
    static let historyOptions = [10, 20, 30, 40, 50]

    // ウィンドウ幅
    @Published var popupWidth: Double {
        didSet { UserDefaults.standard.set(popupWidth, forKey: Keys.popupWidth) }
    }
    static let widthOptions: [Double] = [300, 400, 500, 600]

    // 最大高さ比率
    @Published var popupMaxHeightRatio: Double {
        didSet { UserDefaults.standard.set(popupMaxHeightRatio, forKey: Keys.popupHeightRatio) }
    }
    static let heightRatioOptions: [(label: String, value: Double)] = [
        ("40%", 0.4), ("60%", 0.6), ("80%", 0.8)
    ]

    // 文字サイズ
    @Published var fontSizeScale: FontSizeScale {
        didSet { UserDefaults.standard.set(fontSizeScale.rawValue, forKey: Keys.fontSizeScale) }
    }

    // 貼り付け診断ログ（既定 OFF。キーは PasteLog 側と共有）
    @Published var pasteLogging: Bool {
        didSet { UserDefaults.standard.set(pasteLogging, forKey: PasteLog.defaultsKey) }
    }

    // 自動起動
    @Published private(set) var launchAtLogin: Bool = false

    private init() {
        let storedCount = UserDefaults.standard.integer(forKey: Keys.maxHistoryCount)
        maxHistoryCount = storedCount > 0 ? storedCount : 30

        let storedWidth = UserDefaults.standard.double(forKey: Keys.popupWidth)
        popupWidth = storedWidth > 0 ? storedWidth : 400

        let storedRatio = UserDefaults.standard.double(forKey: Keys.popupHeightRatio)
        popupMaxHeightRatio = storedRatio > 0 ? storedRatio : 0.6

        let storedScale = UserDefaults.standard.string(forKey: Keys.fontSizeScale)
        fontSizeScale = FontSizeScale(rawValue: storedScale ?? "") ?? .medium

        pasteLogging = UserDefaults.standard.bool(forKey: PasteLog.defaultsKey)

        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
