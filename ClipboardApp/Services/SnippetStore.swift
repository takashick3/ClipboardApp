import Foundation
import AppKit

class SnippetStore: ObservableObject {
    static let shared = SnippetStore()

    @Published private(set) var folders: [SnippetFolder] = []

    private let fileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ClipboardApp", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("snippets.xml")
    }()

    private init() {
        load()
    }

    // MARK: - CRUD

    func addFolder(_ folder: SnippetFolder = SnippetFolder()) {
        folders.append(folder)
        save()
    }

    func deleteFolder(id: UUID) {
        folders.removeAll { $0.id == id }
        save()
    }

    func updateFolder(id: UUID, title: String) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].title = title
        save()
    }

    func moveFolder(from source: IndexSet, to destination: Int) {
        folders.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func addSnippet(_ snippet: Snippet = Snippet(), toFolder folderID: UUID) {
        guard let idx = folders.firstIndex(where: { $0.id == folderID }) else { return }
        folders[idx].snippets.append(snippet)
        save()
    }

    func deleteSnippet(id: UUID, fromFolder folderID: UUID) {
        guard let fi = folders.firstIndex(where: { $0.id == folderID }) else { return }
        folders[fi].snippets.removeAll { $0.id == id }
        save()
    }

    func updateSnippet(id: UUID, inFolder folderID: UUID, title: String, content: String) {
        guard let fi = folders.firstIndex(where: { $0.id == folderID }),
              let si = folders[fi].snippets.firstIndex(where: { $0.id == id }) else { return }
        folders[fi].snippets[si].title = title
        folders[fi].snippets[si].content = content
        save()
    }

    func moveSnippet(inFolder folderID: UUID, from source: IndexSet, to destination: Int) {
        guard let fi = folders.firstIndex(where: { $0.id == folderID }) else { return }
        folders[fi].snippets.move(fromOffsets: source, toOffset: destination)
        save()
    }

    // MARK: - Persistence (Clipy-compatible XML)

    func save() {
        let xml = buildXML()
        try? xml.xmlData(options: .nodePrettyPrint).write(to: fileURL)
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let doc = try? XMLDocument(data: data) else { return }
        folders = parseFolders(from: doc)
    }

    // MARK: - Export / Import

    func exportXML() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.xml]
        panel.nameFieldStringValue = "snippets.xml"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self = self else { return }
            let xml = self.buildXML()
            try? xml.xmlData(options: .nodePrettyPrint).write(to: url)
        }
    }

    func importXML() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.xml]
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self = self else { return }
            guard let data = try? Data(contentsOf: url),
                  let doc = try? XMLDocument(data: data) else { return }
            let imported = self.parseFolders(from: doc)
            DispatchQueue.main.async {
                self.folders = imported
                self.save()
            }
        }
    }

    // MARK: - XML Helpers

    private func buildXML() -> XMLDocument {
        let root = XMLElement(name: "folders")
        for folder in folders {
            let folderEl = XMLElement(name: "folder")
            folderEl.addChild(XMLElement(name: "title", stringValue: folder.title))
            let snippetsEl = XMLElement(name: "snippets")
            for snippet in folder.snippets {
                let snippetEl = XMLElement(name: "snippet")
                snippetEl.addChild(XMLElement(name: "title", stringValue: snippet.title))
                snippetEl.addChild(XMLElement(name: "content", stringValue: snippet.content))
                snippetsEl.addChild(snippetEl)
            }
            folderEl.addChild(snippetsEl)
            root.addChild(folderEl)
        }
        let doc = XMLDocument(rootElement: root)
        doc.version = "1.0"
        doc.characterEncoding = "UTF-8"
        return doc
    }

    private func parseFolders(from doc: XMLDocument) -> [SnippetFolder] {
        guard let root = doc.rootElement() else { return [] }
        return (root.elements(forName: "folder")).compactMap { folderEl in
            guard let title = folderEl.elements(forName: "title").first?.stringValue else { return nil }
            let snippets = folderEl.elements(forName: "snippets").first?
                .elements(forName: "snippet").compactMap { snippetEl -> Snippet? in
                    guard let sTitle = snippetEl.elements(forName: "title").first?.stringValue,
                          let content = snippetEl.elements(forName: "content").first?.stringValue else { return nil }
                    return Snippet(title: sTitle, content: content)
                } ?? []
            return SnippetFolder(title: title, snippets: snippets)
        }
    }
}
