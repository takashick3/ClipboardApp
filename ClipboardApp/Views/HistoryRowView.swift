import SwiftUI

struct HistoryRowView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let isPinned: Bool
    let fontSizeScale: FontSizeScale
    var onTogglePin: () -> Void

    @State private var isHoveringIcon = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onTogglePin) {
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                    .frame(width: 16)
            }
            .buttonStyle(.plain)
            .onHover { isHoveringIcon = $0 }

            Text(preview)
                .font(fontSizeScale.rowFont)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, fontSizeScale.rowVerticalPadding)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(4)
    }

    private var iconName: String {
        // ホバー中はピン操作を優先（選択中でも同様）
        if isHoveringIcon {
            return isPinned ? "pin.slash" : "pin.fill"
        }
        if isSelected { return "chevron.right" }
        return isPinned ? "pin.fill" : "list.bullet.clipboard"
    }

    private var iconColor: Color {
        if isHoveringIcon {
            return isPinned ? .secondary : .accentColor
        }
        if isSelected { return .accentColor }
        return isPinned ? .accentColor : .secondary
    }

    private var preview: String {
        let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let single = trimmed.replacingOccurrences(of: "\n", with: " ")
        return single.count > 50 ? String(single.prefix(50)) + "…" : single
    }
}
