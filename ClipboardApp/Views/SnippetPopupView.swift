import SwiftUI

struct SnippetPopupView: View {
    @ObservedObject var store: SnippetStore
    @ObservedObject var state: PopupStateModel
    var onSelect: (String) -> Void

    var body: some View {
        Group {
            if store.folders.isEmpty {
                Text("スニペットがありません")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(20)
            } else if let folder = state.selectedSnippetFolder {
                snippetList(folder: folder)
            } else {
                folderList
            }
        }
    }

    private var folderList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(store.folders.enumerated()), id: \.element.id) { index, folder in
                        FolderRowView(
                            folder: folder,
                            isSelected: state.selectedIndex == index
                        )
                        .id(index)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            state.selectedSnippetFolder = folder
                            state.selectedIndex = 0
                        }
                    }
                }
                .padding(4)
            }
            .frame(maxHeight: NSScreen.main.map { $0.visibleFrame.height * AppSettings.shared.popupMaxHeightRatio } ?? 400)
            .onChange(of: state.selectedIndex) { newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
    }

    private func snippetList(folder: SnippetFolder) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 2) {
                    // Back row
                    BackRowView(title: folder.title, isSelected: state.selectedIndex == -1)
                        .id(-1)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            state.selectedSnippetFolder = nil
                            state.selectedIndex = store.folders.firstIndex(where: { $0.id == folder.id }) ?? 0
                        }

                    ForEach(Array(folder.snippets.enumerated()), id: \.element.id) { index, snippet in
                        SnippetRowView(
                            snippet: snippet,
                            isSelected: state.selectedIndex == index
                        )
                        .id(index)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(snippet.content)
                        }
                    }
                }
                .padding(4)
            }
            .frame(maxHeight: NSScreen.main.map { $0.visibleFrame.height * AppSettings.shared.popupMaxHeightRatio } ?? 400)
            .onChange(of: state.selectedIndex) { newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
    }
}

// MARK: - Row Views

private struct FolderRowView: View {
    let folder: SnippetFolder
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isSelected ? "chevron.right" : "folder")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 16)
            Text(folder.title)
                .font(.body)
                .lineLimit(1)
                .foregroundColor(.primary)
            Spacer()
            Text("\(folder.snippets.count)")
                .font(.caption)
                .foregroundColor(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(4)
    }
}

private struct BackRowView: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.left")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 16)
            Text(title)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .accentColor : .primary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(4)
    }
}

private struct SnippetRowView: View {
    let snippet: Snippet
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isSelected ? "chevron.right" : "doc.text")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(snippet.title)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                if !snippet.content.isEmpty {
                    Text(snippet.content.replacingOccurrences(of: "\n", with: " "))
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(4)
    }
}
