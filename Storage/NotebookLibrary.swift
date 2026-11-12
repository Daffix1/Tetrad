import Combine
import Foundation

@MainActor
final class NotebookLibrary: ObservableObject {
    @Published private(set) var notebooks: [Notebook] = []

    private let storage: PageStorage
    private var recentPages: [String: Int] = [:]

    private enum Key {
        static let notebooks = "notebooks"
        static let recentPages = "recentNotebookPages"
        static let prototypePage = "prototype.page.strokes"
    }

    init(storage: PageStorage = .standard) {
        self.storage = storage
        load()
    }

    func notebook(withID id: UUID) -> Notebook? {
        notebooks.first { $0.id == id }
    }

    func create(title: String, paper: PaperStyle) -> Notebook {
        let notebook = Notebook(id: UUID(), title: normalizedTitle(title), paper: paper)
        add(notebook)
        return notebook
    }

    func add(_ notebook: Notebook) {
        notebooks.append(notebook)
        saveNotebooks()
    }

    func updateSettings(for id: UUID, title: String, paper: PaperStyle) {
        guard var notebook = notebook(withID: id) else { return }
        notebook.title = normalizedTitle(title)
        notebook.paper = paper
        replace(notebook)
    }

    func replace(_ notebook: Notebook) {
        guard let index = notebooks.firstIndex(where: { $0.id == notebook.id }) else { return }
        notebooks[index] = notebook
        saveNotebooks()
    }

    func delete(_ notebook: Notebook) {
        notebooks.removeAll { $0.id == notebook.id }
        saveNotebooks()
        recentPages.removeValue(forKey: notebook.id.uuidString)
        saveRecentPages()
        storage.removePage(notebook.coverStorageKey)
        for leaf in notebook.leaves {
            storage.removePage(notebook.storageKey(forLeaf: leaf))
        }
    }

    func lastPage(in notebook: Notebook) -> Int {
        let number = recentPages[notebook.id.uuidString] ?? 0
        return min(max(number, 0), notebook.pageCount - 1)
    }

    func rememberPage(_ number: Int, in id: UUID) {
        recentPages[id.uuidString] = number
        saveRecentPages()
    }

    private func load() {
        recentPages = decode([String: Int].self, for: Key.recentPages) ?? [:]
        if let saved = decode([Notebook].self, for: Key.notebooks) {
            notebooks = saved
        } else if storage.defaults.data(forKey: Key.notebooks)?.isEmpty != false,
                  let draft = storage.defaults.data(forKey: Key.prototypePage) {
            let notebook = Notebook(id: UUID(), title: "Первая тетрадь")
            storage.writeStrokeData(draft, for: notebook.storageKey(for: 0))
            add(notebook)
        }
    }

    private func normalizedTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Без названия" : trimmed
    }

    private func saveNotebooks() {
        save(notebooks, for: Key.notebooks)
    }

    private func saveRecentPages() {
        save(recentPages, for: Key.recentPages)
    }

    private func decode<Value: Decodable>(_ type: Value.Type, for key: String) -> Value? {
        guard let data = storage.defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save<Value: Encodable>(_ value: Value, for key: String) {
        if let data = try? JSONEncoder().encode(value) {
            storage.defaults.set(data, forKey: key)
        }
    }
}
