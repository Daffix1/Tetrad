import SwiftUI

struct TetradRootView: View {
    @StateObject private var library = NotebookLibrary()
    @StateObject private var edits = PageEdits()
    @State private var selectedNotebookID: UUID?
    @State private var opensCover = false
    @State private var brush = Brush()
    @State private var isErasing = false

    var body: some View {
        if let id = selectedNotebookID, let notebook = library.notebook(withID: id) {
            NotebookEditor(
                library: library, notebook: notebook, initialPage: library.lastPage(in: notebook),
                edits: edits, brush: $brush, isErasing: $isErasing, opensCover: opensCover
            ) {
                selectedNotebookID = nil
            }
            .id(id)
        } else {
            NotebookShelf(library: library, open: { open($0) },
                          editCover: { open($0, onCover: true) }, delete: delete)
        }
    }

    private func open(_ id: UUID, onCover: Bool = false) {
        opensCover = onCover
        selectedNotebookID = id
    }

    private func delete(_ notebook: Notebook) {
        edits.forget(notebook.coverStorageKey)
        for leaf in notebook.leaves {
            edits.forget(notebook.storageKey(forLeaf: leaf))
        }
        library.delete(notebook)
    }
}
