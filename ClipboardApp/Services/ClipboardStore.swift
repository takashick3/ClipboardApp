import Foundation
import Combine

class ClipboardStore: ObservableObject {
    static let shared = ClipboardStore()

    @Published private(set) var items: [ClipboardItem] = []

    private var maxCount: Int = 30
    private let userDefaultsKey = "clipboard_history"

    private init() {
        load()
        // AppSettings は ClipboardStore より後に初期化されるため didSet 経由ではなく直接反映
        let saved = UserDefaults.standard.integer(forKey: "max_history_count")
        if saved > 0 { maxCount = saved }
    }

    func applyMaxCount(_ count: Int) {
        maxCount = count
        if items.count > count {
            items = Array(items.prefix(count))
            save()
        }
    }

    func add(_ text: String) {
        let item = ClipboardItem(text: text)
        items.insert(item, at: 0)
        if items.count > maxCount {
            items = Array(items.prefix(maxCount))
        }
        save()
    }

    func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) else { return }
        items = decoded
    }
}
