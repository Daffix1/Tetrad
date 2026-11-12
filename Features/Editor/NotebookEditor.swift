import SwiftUI
import UniformTypeIdentifiers

struct NotebookEditor: View {
    @ObservedObject var library: NotebookLibrary
    let notebook: Notebook
    @ObservedObject var edits: PageEdits
    @Binding var brush: Brush
    @Binding var isErasing: Bool
    let close: () -> Void
    private let opensCover: Bool

    @State private var page: Int
    @State private var isEditingCover: Bool
    @State private var swipeDirection = 1
    @State private var openToolPanel: EditorTools.Panel?
    @State private var selectedPreset: Int?
    @State private var showContents = false
    @State private var showSettings = false
    @State private var showImport = false
    @State private var share: SharedFile?
    @State private var message: String?
    @AppStorage("eraserWidth") private var eraserWidth = 16.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(library: NotebookLibrary, notebook: Notebook, initialPage: Int, edits: PageEdits,
         brush: Binding<Brush>, isErasing: Binding<Bool>, opensCover: Bool, close: @escaping () -> Void) {
        self.library = library
        self.notebook = notebook
        self.edits = edits
        _brush = brush
        _isErasing = isErasing
        self.close = close
        self.opensCover = opensCover
        _page = State(initialValue: initialPage)
        _isEditingCover = State(initialValue: opensCover)
    }

    var body: some View {
        let key = isEditingCover ? notebook.coverStorageKey : notebook.storageKey(for: page)
        VStack(spacing: 8) {
            if isEditingCover {
                coverHeader
            } else {
                notebookHeader
            }
            editingToolbar(for: key)
            canvas(for: key)
                .overlay(alignment: .top) {
                    if let openToolPanel {
                        toolSettingsOverlay(for: openToolPanel)
                    }
                }
        }
        .frame(width: PageLayout.bounds.width)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(NotebookTheme.ink)
        .tint(NotebookTheme.accent)
        .background(NotebookTheme.background.ignoresSafeArea())
        .sheet(isPresented: $showContents) {
            NotebookContents(library: library, notebookID: notebook.id, current: $page, select: { number in
                openPage(number)
                showContents = false
            }, change: updateLeaves)
        }
        .sheet(isPresented: $showSettings) {
            NotebookSettingsForm(title: "Настройки тетради", actionTitle: "Сохранить",
                                 save: { title, paper in
                library.updateSettings(for: notebook.id, title: title, paper: paper)
            }, name: notebook.title, paper: notebook.paperStyle)
        }
        .sheet(item: $share) { file in ShareSheet(url: file.url) }
        .fileImporter(isPresented: $showImport, allowedContentTypes: [.pdf, .jpeg, .png],
                      allowsMultipleSelection: true, onCompletion: importPages)
        .alert("Тетрадь", isPresented: Binding(get: { message != nil }, set: {
            if !$0 { message = nil }
        })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private var coverHeader: some View {
        HStack {
            Text("Обложка · \(notebook.title)")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button("Готово") {
                openToolPanel = nil
                if opensCover {
                    close()
                } else {
                    isEditingCover = false
                }
            }
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 8)
    }

    private var notebookHeader: some View {
        HStack(spacing: 8) {
            Button(action: close) {
                Label("Тетради", systemImage: "chevron.left")
                    .padding(.horizontal, 8)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            Spacer(minLength: 0)
            notebookMenu
            Spacer(minLength: 0)
            Button(action: appendPage) {
                Label("Добавить лист", systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .help("Добавить лист")
            .disabled(notebook.pageCount >= Notebook.maximumPageCount)
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 8)
    }

    private var notebookMenu: some View {
        Menu {
            Button("Подписать обложку", systemImage: "pencil.and.outline") {
                openToolPanel = nil
                isEditingCover = true
            }
            Button("Название и бумага") { showSettings = true }
            Button("Добавить PDF, JPG или PNG", systemImage: "doc.badge.plus") { showImport = true }
                .disabled(notebook.pageCount >= Notebook.maximumPageCount)
            Button("Лист в PDF") { exportPDF(pages: [page]) }
            Button("Тетрадь в PDF") { exportPDF(pages: Array(notebook.leaves.indices)) }
            Button("Резервная копия", action: backup)
        } label: {
            HStack(spacing: 7) {
                Text(notebook.title)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(NotebookTheme.ink)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
    }

    private func editingToolbar(for key: String) -> some View {
        HStack(spacing: 12) {
            if isEditingCover {
                Text("Подпись на обложке")
                    .foregroundStyle(.secondary)
                    .padding(.leading, 10)
            } else {
                Button {
                    showContents = true
                } label: {
                    Label {
                        Text("Лист \(page + 1) из \(notebook.pageCount)")
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "square.grid.2x2")
                    }
                    .padding(.horizontal, 10)
                    .frame(minHeight: 44)
                    .background(NotebookTheme.selection, in: RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityHint("Открывает оглавление")
            }

            Spacer(minLength: 0)
            EditorTools(brush: $brush, isErasing: $isErasing, openPanel: $openToolPanel)
            Spacer(minLength: 0)

            HStack(spacing: 0) {
                historyButton("Отменить", icon: "arrow.uturn.backward") { edits.undo(key) }
                    .disabled(!edits.canUndo(key))
                historyButton("Повторить", icon: "arrow.uturn.forward") { edits.redo(key) }
                    .disabled(!edits.canRedo(key))
            }
        }
        .font(.subheadline.weight(.medium))
        .padding(4)
        .background(NotebookTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(NotebookTheme.border)
                .allowsHitTesting(false)
        }
        .padding(.bottom, 4)
    }

    private func toolSettingsOverlay(for panel: EditorTools.Panel) -> some View {
        EditorToolSettings(panel: panel, brush: $brush, eraserWidth: $eraserWidth,
                           selectedPreset: $selectedPreset)
            .accessibilityAction(.escape, dismissToolSettings)
    }

    private func dismissToolSettings() {
        if openToolPanel != nil { openToolPanel = nil }
    }

    private func historyButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .help(title)
    }

    private func canvas(for key: String) -> some View {
        ZStack {
            PageCanvas(storageKey: key, brush: brush, isErasing: isErasing,
                       style: isEditingCover ? .blank : notebook.paperStyle, eraserWidth: eraserWidth,
                       transparentBackground: isEditingCover, edits: edits,
                       turnPage: swipe, onPaperInteraction: dismissToolSettings)
                .id(key)
                .transition(.asymmetric(
                    insertion: .offset(x: CGFloat(swipeDirection) * PageLayout.bounds.width),
                    removal: .offset(x: -CGFloat(swipeDirection) * PageLayout.bounds.width)
                ))
                .accessibilityLabel(isEditingCover ? "Обложка для письма стилусом" : "Лист для письма стилусом")
        }
        .frame(width: PageLayout.bounds.width,
               height: isEditingCover ? PageLayout.coverLabelBounds.height : PageLayout.bounds.height)
        .clipped()
        .background {
            Group {
                if isEditingCover {
                    Rectangle().fill(NotebookTheme.coverColor(for: notebook.id).gradient)
                } else {
                    Rectangle().fill(Color(uiColor: PageRenderer.paperColor))
                }
            }
            .shadow(color: .black.opacity(0.13), radius: 10, x: 0, y: 4)
        }
    }

    private func swipe(_ direction: Int) {
        let next = page + direction
        guard !isEditingCover, notebook.leaves.indices.contains(next) else { return }
        swipeDirection = direction
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) {
            openPage(next)
        }
    }

    private func openPage(_ number: Int) {
        page = number
        library.rememberPage(number, in: notebook.id)
    }

    private func appendPage() {
        guard notebook.pageCount < Notebook.maximumPageCount else { return }
        var updated = notebook
        updated.setLeaves(notebook.leaves + [UUID().uuidString])
        library.replace(updated)
        openPage(updated.pageCount - 1)
    }

    private func updateLeaves(_ leaves: [String], removed: String?) {
        guard var updated = library.notebook(withID: notebook.id) else { return }
        let active = updated.leaves[page]
        updated.setLeaves(leaves)
        library.replace(updated)
        openPage(leaves.firstIndex(of: active) ?? min(page, leaves.count - 1))

        if let removed {
            let key = updated.storageKey(forLeaf: removed)
            edits.forget(key)
            PageStorage.standard.removePage(key)
        }
    }

    private func importPages(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard !urls.isEmpty, let current = library.notebook(withID: notebook.id) else { return }
            let updated = try PageFileImporter().appendingPages(from: urls, to: current)
            library.replace(updated)
            openPage(current.pageCount)
        } catch {
            message = error.localizedDescription
        }
    }

    private func exportPDF(pages: [Int]) {
        do {
            share = SharedFile(url: try NotebookFiles().exportPDF(notebook, pages: pages))
        } catch {
            message = "Не удалось сохранить файл для отправки."
        }
    }

    private func backup() {
        do {
            share = SharedFile(url: try NotebookFiles().backup(notebook, currentPage: page))
        } catch {
            message = "Не удалось создать резервную копию."
        }
    }
}
