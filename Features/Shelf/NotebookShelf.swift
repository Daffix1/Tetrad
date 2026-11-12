import SwiftUI
import UniformTypeIdentifiers

struct NotebookShelf: View {
    @ObservedObject var library: NotebookLibrary
    let open: (UUID) -> Void
    let editCover: (UUID) -> Void
    let delete: (Notebook) -> Void

    @State private var showCreation = false
    @State private var showRestore = false
    @State private var showRestoreError = false
    @State private var pendingDeletion: Notebook?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    if library.notebooks.isEmpty {
                        ContentUnavailableView("Полка пуста", systemImage: "books.vertical")
                            .padding(.vertical, 44)
                    } else {
                        covers
                    }
                }
                .padding(28)
                .frame(maxWidth: 920)
                .frame(maxWidth: .infinity)
            }
            .background(NotebookTheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .foregroundStyle(NotebookTheme.ink)
        }
        .tint(NotebookTheme.accent)
        .sheet(isPresented: $showCreation) {
            NotebookSettingsForm(title: "Новая тетрадь", actionTitle: "Создать") { name, paper in
                open(library.create(title: name, paper: paper).id)
            }
        }
        .fileImporter(isPresented: $showRestore, allowedContentTypes: [.json], onCompletion: restore)
        .confirmationDialog("Удалить тетрадь?", isPresented: Binding(get: { pendingDeletion != nil }, set: {
            if !$0 { pendingDeletion = nil }
        }), titleVisibility: .visible, presenting: pendingDeletion) { notebook in
            Button("Удалить «\(notebook.title)»", role: .destructive) { delete(notebook) }
        } message: { _ in
            Text("Все листы и записи этой тетради будут удалены.")
        }
        .alert("Тетрадь", isPresented: $showRestoreError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Не удалось открыть резервную копию «Тетради».")
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                title
                Spacer(minLength: 0)
                shelfActions
            }
            VStack(alignment: .leading, spacing: 14) {
                title
                shelfActions
            }
        }
        .padding(.vertical, 12)
    }

    private var title: some View {
        Text("Тетради")
            .font(.system(.largeTitle, design: .serif).weight(.semibold))
            .accessibilityAddTraits(.isHeader)
    }

    private var shelfActions: some View {
        HStack(spacing: 12) {
            Button {
                showRestore = true
            } label: {
                Label("Восстановить копию", systemImage: "square.and.arrow.down")
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .help("Восстановить копию")

            Button {
                showCreation = true
            } label: {
                Label("Новая тетрадь", systemImage: "plus")
                    .foregroundStyle(.white)
            }
            .buttonStyle(.borderedProminent)
            .tint(NotebookTheme.primaryButton)
            .controlSize(.large)
        }
    }

    private var covers: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 176), spacing: 22)], spacing: 26) {
            ForEach(library.notebooks) { notebook in
                ZStack(alignment: .topTrailing) {
                    Button {
                        open(notebook.id)
                    } label: {
                        NotebookCover(notebook: notebook)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { coverActions(for: notebook) }
                    .accessibilityAction(named: Text("Удалить тетрадь")) {
                        pendingDeletion = notebook
                    }

                    Menu {
                        coverActions(for: notebook)
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Действия с тетрадью «\(notebook.title)»")
                    .padding(5)
                }
            }
        }
    }

    @ViewBuilder
    private func coverActions(for notebook: Notebook) -> some View {
        Button("Подписать обложку", systemImage: "pencil.and.outline") {
            editCover(notebook.id)
        }
        Button("Удалить тетрадь", systemImage: "trash", role: .destructive) {
            pendingDeletion = notebook
        }
    }

    private func restore(_ result: Result<URL, Error>) {
        do {
            let restored = try NotebookFiles().restore(from: result.get())
            library.add(restored.notebook)
            library.rememberPage(restored.page, in: restored.notebook.id)
            open(restored.notebook.id)
        } catch {
            showRestoreError = true
        }
    }
}
