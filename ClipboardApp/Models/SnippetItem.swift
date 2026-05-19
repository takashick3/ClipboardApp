import Foundation

struct SnippetFolder: Identifiable {
    var id: UUID = UUID()
    var title: String
    var snippets: [Snippet]

    init(id: UUID = UUID(), title: String = "新規フォルダ", snippets: [Snippet] = []) {
        self.id = id
        self.title = title
        self.snippets = snippets
    }
}

struct Snippet: Identifiable {
    var id: UUID = UUID()
    var title: String
    var content: String

    init(id: UUID = UUID(), title: String = "新規スニペット", content: String = "") {
        self.id = id
        self.title = title
        self.content = content
    }
}
