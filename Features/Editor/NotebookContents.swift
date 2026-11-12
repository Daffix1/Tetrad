import SwiftUI
import UIKit

struct NotebookContents: View {
    @ObservedObject var library: NotebookLibrary
    let notebookID: UUID
    @Binding var current: Int
    let select: (Int) -> Void
    let change: ([String], String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pendingDeletion: Int?
    @State private var dropTarget: String?

    var body: some View {
        if let notebook = library.notebook(withID: notebookID) {
            contents(of: notebook)
        }
    }

    private func contents(of notebook: Notebook) -> some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 16)], spacing: 16) {
                    ForEach(Array(notebook.leaves.enumerated()), id: \.element) { number, leaf in
                        tile(number, leaf: leaf, in: notebook)
                    }
                }
                .padding()
            }
            .navigationTitle("Оглавление")
            .toolbar { Button("Готово") { dismiss() } }
            .alert("Удалить лист?", isPresented: Binding(get: { pendingDeletion != nil }, set: {
                if !$0 { pendingDeletion = nil }
            })) {
                Button("Отмена", role: .cancel) { pendingDeletion = nil }
                Button("Удалить", role: .destructive) {
                    guard let number = pendingDeletion else { return }
                    var leaves = notebook.leaves
                    let removed = leaves.remove(at: number)
                    change(leaves, removed)
                    pendingDeletion = nil
                }
            } message: {
                Text("Лист и записи на нём будут удалены.")
            }
        }
    }

    private func tile(_ number: Int, leaf: String, in notebook: Notebook) -> some View {
        VStack(spacing: 4) {
            Button {
                select(number)
            } label: {
                VStack {
                    PageThumbnail(key: notebook.storageKey(for: number), style: notebook.paperStyle)
                    Text("Лист \(number + 1)").font(.caption)
                }
            }
            .buttonStyle(.plain)
            .onDrag { NSItemProvider(object: dragToken(leaf, in: notebook) as NSString) }
            .padding(5)
            .background(number == current ? Color.accentColor.opacity(0.2) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8))
            .accessibilityAddTraits(number == current ? .isSelected : [])
            Menu {
                Button("Вставить лист после", systemImage: "plus.rectangle") {
                    var leaves = notebook.leaves
                    guard leaves.count < Notebook.maximumPageCount, let index = leaves.firstIndex(of: leaf) else { return }
                    leaves.insert(UUID().uuidString, at: index + 1)
                    change(leaves, nil)
                }
                .disabled(notebook.pageCount >= Notebook.maximumPageCount)
                Button("Удалить лист", systemImage: "trash", role: .destructive) {
                    pendingDeletion = number
                }
                .disabled(notebook.pageCount == 1)
            } label: {
                Image(systemName: "ellipsis.circle").frame(width: 44, height: 34)
            }
            .accessibilityLabel("Действия с листом \(number + 1)")
        }
        .dropDestination(for: String.self) { tokens, _ in
            guard let token = tokens.first, notebook.leaves.contains(where: { dragToken($0, in: notebook) == token })
            else { return false }
            move(token, to: leaf, in: notebook)
            return true
        } isTargeted: { targeted in
            dropTarget = targeted ? leaf : (dropTarget == leaf ? nil : dropTarget)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.accentColor, lineWidth: dropTarget == leaf ? 2 : 0)
                .allowsHitTesting(false)
        }
    }

    private func dragToken(_ leaf: String, in notebook: Notebook) -> String {
        "\(notebook.id.uuidString)/\(leaf)"
    }

    private func move(_ token: String, to target: String, in notebook: Notebook) {
        var leaves = notebook.leaves
        guard let source = leaves.firstIndex(where: { dragToken($0, in: notebook) == token }),
              let destination = leaves.firstIndex(of: target),
              source != destination else { return }
        leaves.insert(leaves.remove(at: source), at: destination)
        withAnimation(.easeInOut(duration: 0.22)) {
            change(leaves, nil)
        }
    }
}

private struct PageThumbnail: View {
    let key: String
    let style: PaperStyle
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Color(uiColor: PageRenderer.paperColor)
            }
        }
        .frame(width: 92, height: 119)
        .accessibilityHidden(true)
        .task {
            if image == nil { image = PageRenderer.image(key: key, style: style, scale: 0.25) }
        }
    }
}
