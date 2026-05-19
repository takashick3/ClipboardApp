import SwiftUI

struct SnippetSettingsTab: View {
    @ObservedObject private var store = SnippetStore.shared
    @State private var selectedFolderID: UUID? = nil
    @State private var editingFolderID: UUID? = nil
    @State private var editingFolderTitle: String = ""
    @FocusState private var folderFieldFocused: Bool
    @State private var selectedSnippetID: UUID? = nil
    @State private var editingSnippetID: UUID? = nil
    @State private var editingSnippetTitle: String = ""
    @State private var editingSnippetContent: String = ""

    private var selectedFolder: SnippetFolder? {
        store.folders.first { $0.id == selectedFolderID }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("インポート") { store.importXML() }
                Button("エクスポート") { store.exportXML() }
                    .disabled(store.folders.isEmpty)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            HSplitView {
                folderPane
                    .frame(minWidth: 150, maxWidth: 200)
                snippetPane
                    .frame(minWidth: 200, maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
            .onChange(of: selectedFolderID) { _ in
                selectedSnippetID = nil
            }
        }
    }

    // MARK: - Folder Pane

    private var folderPane: some View {
        VStack(spacing: 0) {
            List {
                ForEach(store.folders) { folder in
                    Group {
                        if editingFolderID == folder.id {
                            TextField("フォルダ名", text: $editingFolderTitle, onCommit: commitFolderEdit)
                                .textFieldStyle(.plain)
                                .focused($folderFieldFocused)
                        } else {
                            Text(folder.title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selectedFolderID = folder.id }
                    .listRowBackground(
                        selectedFolderID == folder.id
                            ? Color.accentColor.opacity(0.2)
                            : Color.clear
                    )
                }
                .onMove { indices, destination in
                    store.moveFolder(from: indices, to: destination)
                }
            }
            .listStyle(.plain)

            Divider()
            HStack(spacing: 0) {
                Button { store.addFolder(); selectedFolderID = store.folders.last?.id } label: {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 24)
                }
                .buttonStyle(.plain)
                Button {
                    if let id = selectedFolderID { store.deleteFolder(id: id) }
                    selectedFolderID = store.folders.first?.id
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 28, height: 24)
                }
                .buttonStyle(.plain)
                .disabled(selectedFolderID == nil)
                Button {
                    if let folder = selectedFolder { beginFolderEdit(folder) }
                } label: {
                    Image(systemName: "pencil")
                        .frame(width: 28, height: 24)
                }
                .buttonStyle(.plain)
                .disabled(selectedFolderID == nil || editingFolderID != nil)
                Spacer()
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Snippet Pane

    private var snippetPane: some View {
        VStack(spacing: 0) {
            if let folder = selectedFolder {
                if editingSnippetID != nil {
                    snippetEditForm(folder: folder)
                } else {
                    snippetListView(folder: folder)
                }
            } else {
                Text("フォルダを選択してください")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func snippetListView(folder: SnippetFolder) -> some View {
        VStack(spacing: 0) {
            List {
                ForEach(folder.snippets) { snippet in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snippet.title)
                            .font(.body)
                        Text(snippet.content.replacingOccurrences(of: "\n", with: " "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedSnippetID = snippet.id }
                    .simultaneousGesture(TapGesture(count: 2).onEnded {
                        selectedSnippetID = snippet.id
                        beginSnippetEdit(snippet)
                    })
                    .listRowBackground(
                        selectedSnippetID == snippet.id
                            ? Color.accentColor.opacity(0.2)
                            : Color.clear
                    )
                }
                .onMove { indices, destination in
                    store.moveSnippet(inFolder: folder.id, from: indices, to: destination)
                }
            }
            .listStyle(.plain)

            Divider()
            HStack(spacing: 0) {
                Button {
                    let s = Snippet()
                    store.addSnippet(s, toFolder: folder.id)
                    if let added = store.folders.first(where: { $0.id == folder.id })?.snippets.last {
                        selectedSnippetID = added.id
                        beginSnippetEdit(added)
                    }
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 24)
                }
                .buttonStyle(.plain)
                Button {
                    if let id = selectedSnippetID {
                        store.deleteSnippet(id: id, fromFolder: folder.id)
                        selectedSnippetID = nil
                    }
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 28, height: 24)
                }
                .buttonStyle(.plain)
                .disabled(selectedSnippetID == nil)
                Spacer()
            }
            .padding(.horizontal, 4)
        }
    }

    private func snippetEditForm(folder: SnippetFolder) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("タイトル", text: $editingSnippetTitle)
                .textFieldStyle(.roundedBorder)
            TextEditor(text: $editingSnippetContent)
                .font(.body)
                .border(Color.secondary.opacity(0.3))
                .frame(maxHeight: .infinity)
            HStack {
                Spacer()
                Button("キャンセル") {
                    if let id = editingSnippetID,
                       folder.snippets.first(where: { $0.id == id })?.title == "新規スニペット",
                       folder.snippets.first(where: { $0.id == id })?.content == "" {
                        store.deleteSnippet(id: id, fromFolder: folder.id)
                    }
                    editingSnippetID = nil
                }
                Button("保存") { commitSnippetEdit(folderID: folder.id) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(8)
    }

    // MARK: - Edit Helpers

    private func beginFolderEdit(_ folder: SnippetFolder) {
        editingFolderID = folder.id
        editingFolderTitle = folder.title
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            folderFieldFocused = true
        }
    }

    private func commitFolderEdit() {
        if let id = editingFolderID {
            store.updateFolder(id: id, title: editingFolderTitle.isEmpty ? "新規フォルダ" : editingFolderTitle)
        }
        editingFolderID = nil
        editingFolderTitle = ""
    }

    private func beginSnippetEdit(_ snippet: Snippet) {
        editingSnippetID = snippet.id
        editingSnippetTitle = snippet.title
        editingSnippetContent = snippet.content
    }

    private func commitSnippetEdit(folderID: UUID) {
        if let id = editingSnippetID {
            store.updateSnippet(
                id: id,
                inFolder: folderID,
                title: editingSnippetTitle.isEmpty ? "新規スニペット" : editingSnippetTitle,
                content: editingSnippetContent
            )
        }
        editingSnippetID = nil
        editingSnippetTitle = ""
        editingSnippetContent = ""
    }
}
