import SwiftUI

struct PinnedRowView: View {
    let item: PinnedItem
    let isSelected: Bool
    let fontSizeScale: FontSizeScale
    var onUnpin: () -> Void

    @State private var isHoveringIcon = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onUnpin) {
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
        if isSelected { return "chevron.right" }
        return isHoveringIcon ? "pin.slash" : "pin.fill"
    }

    private var iconColor: Color {
        if isSelected { return .accentColor }
        return isHoveringIcon ? .secondary : .accentColor
    }

    private var preview: String {
        let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let single = trimmed.replacingOccurrences(of: "\n", with: " ")
        return single.count > 50 ? String(single.prefix(50)) + "…" : single
    }
}
