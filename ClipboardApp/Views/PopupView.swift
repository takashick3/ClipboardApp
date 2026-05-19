import SwiftUI

struct PopupView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var selectionModel: SelectedIndexModel
    @ObservedObject private var settings = AppSettings.shared
    var onSelect: (ClipboardItem) -> Void
    var onClose: () -> Void
    var onOpenSettings: () -> Void

    private var displayItems: [ClipboardItem] {
        Array(store.items.prefix(settings.maxHistoryCount))
    }

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
            Text("\(displayItems.count)件")
                .font(.caption)
                .foregroundColor(.secondary)
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.secondary)
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var content: some View {
        Group {
            if displayItems.isEmpty {
                Text("履歴がありません")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(20)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                                HistoryRowView(item: item, isSelected: selectionModel.value == index)
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
                    .onChange(of: selectionModel.value) { newValue in
                        withAnimation {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
    }
}
