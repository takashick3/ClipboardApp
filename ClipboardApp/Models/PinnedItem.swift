import Foundation

struct PinnedItem: Identifiable, Codable {
    var id: UUID = UUID()
    var text: String
    var pinnedAt: Date = Date()
}
