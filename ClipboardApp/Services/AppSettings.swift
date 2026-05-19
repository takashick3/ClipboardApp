import Foundation
import ServiceManagement
import Combine

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let maxHistoryCountKey = "max_history_count"

    @Published var maxHistoryCount: Int {
        didSet {
            UserDefaults.standard.set(maxHistoryCount, forKey: maxHistoryCountKey)
        }
    }

    @Published private(set) var launchAtLogin: Bool = false

    static let historyOptions = [10, 20, 30, 40, 50]

    private init() {
        let stored = UserDefaults.standard.integer(forKey: maxHistoryCountKey)
        maxHistoryCount = stored > 0 ? stored : 30
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
