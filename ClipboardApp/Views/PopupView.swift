import SwiftUI

struct PopupView: View {
    @ObservedObject var store: ClipboardStore
    @Binding var selectedIndex: Int
    var onSelect: (ClipboardItem) -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 400)
        .background(.regularMaterial)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack {
            Image(systemName: "doc.on.clipboard")
                .foregroundColor(.accentColor)
            Text("クリップボード履歴")
                .font(.headline)
            Spacer()
            Text("\(store.items.count)件")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var content: some View {
        Group {
            if store.items.isEmpty {
                Text("履歴がありません")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(20)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                                HistoryRowView(item: item, isSelected: selectedIndex == index)
                                    .id(index)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        onSelect(item)
                                    }
                            }
                        }
                        .padding(4)
                    }
                    .frame(maxHeight: NSScreen.main.map { $0.visibleFrame.height * 0.6 } ?? 400)
                    .onChange(of: selectedIndex) { newValue in
                        withAnimation {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
    }
}
