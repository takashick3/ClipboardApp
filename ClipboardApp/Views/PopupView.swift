import SwiftUI

enum PopupTab {
    case history
    case snippets
}

struct PopupView: View {
    @ObservedObject var clipboardStore: ClipboardStore
    @ObservedObject var snippetStore: SnippetStore
    @ObservedObject var state: PopupStateModel
    @ObservedObject private var settings = AppSettings.shared
    var onSelect: (ClipboardItem) -> Void
    var onSelectSnippet: (String) -> Void
    var onClose: () -> Void
    var onOpenSettings: () -> Void

    private var displayItems: [ClipboardItem] {
        Array(clipboardStore.items.prefix(settings.maxHistoryCount))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tabBar
            Divider()
            content
        }
        .frame(width: settings.popupWidth)
        .background(.regularMaterial)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack {
            Image(systemName: "list.bullet.clipboard")
                .foregroundColor(.accentColor)
            Text("ClipboardApp Ver1.0.0")
                .font(.headline)
            Spacer()
            if state.activeTab == .history {
                Text("\(displayItems.count)件")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "履歴", tab: .history)
            tabButton(title: "スニペット", tab: .snippets)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func tabButton(title: String, tab: PopupTab) -> some View {
        Button(action: {
            state.activeTab = tab
            state.selectedIndex = 0
            state.selectedSnippetFolder = nil
        }) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(state.activeTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                .cornerRadius(6)
                .foregroundColor(state.activeTab == tab ? .accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }

    private var content: some View {
        Group {
            if state.activeTab == .history {
                historyContent
            } else {
                SnippetPopupView(
                    store: snippetStore,
                    state: state,
                    onSelect: onSelectSnippet
                )
            }
        }
    }

    private var historyContent: some View {
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
                                HistoryRowView(
                                    item: item,
                                    isSelected: state.selectedIndex == index,
                                    fontSizeScale: settings.fontSizeScale
                                )
                                .id(index)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onSelect(item)
                                }
                            }
                        }
                        .padding(4)
                    }
                    .frame(maxHeight: NSScreen.main.map { $0.visibleFrame.height * settings.popupMaxHeightRatio } ?? 400)
                    .onChange(of: state.selectedIndex) { newValue in
                        withAnimation {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
    }
}
