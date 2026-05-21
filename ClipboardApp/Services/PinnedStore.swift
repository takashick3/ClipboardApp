import Foundation

class PinnedStore: ObservableObject {
    static let shared = PinnedStore()

    @Published private(set) var items: [PinnedItem] = []

    private let key = "pinned_items"

    private init() { load() }

    // MARK: - CRUD

    func pin(_ text: String) {
        guard !items.contains(where: { $0.text == text }) else { return }
        items.append(PinnedItem(text: text))
        save()
    }

    func unpin(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func isPinned(_ text: String) -> Bool {
        items.contains { $0.text == text }
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([PinnedItem].self, from: data) else { return }
        items = decoded
    }
}
