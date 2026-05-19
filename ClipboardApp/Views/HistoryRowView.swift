import SwiftUI

struct HistoryRowView: View {
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isSelected ? "chevron.right" : "doc.on.clipboard")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 16)

            Text(preview)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(4)
    }

    private var preview: String {
        let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let single = trimmed.replacingOccurrences(of: "\n", with: " ")
        return single.count > 50 ? String(single.prefix(50)) + "…" : single
    }
}
