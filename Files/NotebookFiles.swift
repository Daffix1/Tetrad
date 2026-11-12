import UIKit

struct NotebookFiles {
    var storage = PageStorage.standard

    func exportPDF(_ notebook: Notebook, pages: [Int]) throws -> URL {
        let renderer = UIGraphicsPDFRenderer(bounds: PageLayout.bounds)
        let data = renderer.pdfData { context in
            for number in pages {
                autoreleasepool {
                    context.beginPage()
                    PageRenderer.image(key: notebook.storageKey(for: number),
                                       style: notebook.paperStyle, scale: 2, storage: storage)
                        .draw(in: PageLayout.bounds)
                }
            }
        }
        let name = pages.count == 1 ? "Лист \(pages[0] + 1).pdf" : "Тетрадь.pdf"
        return try shareFile(data, name: name)
    }

    func backup(_ notebook: Notebook, currentPage: Int) throws -> URL {
        let keys = notebook.leaves.map { notebook.storageKey(forLeaf: $0) }
        let snapshot = NotebookBackup(
            title: notebook.title, paper: notebook.paperStyle, current: currentPage,
            pages: keys.map { storage.loadStrokes($0) },
            attachments: keys.map { try? Data(contentsOf: storage.attachmentURL(for: $0)) },
            cover: storage.loadStrokes(notebook.coverStorageKey)
        )
        return try shareFile(JSONEncoder().encode(snapshot), name: "Тетрадь — резервная копия.json")
    }

    func restore(from url: URL) throws -> (notebook: Notebook, page: Int) {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }

        let snapshot = try JSONDecoder().decode(NotebookBackup.self, from: Data(contentsOf: url))
        guard snapshot.version == 1,
              (1...Notebook.maximumPageCount).contains(snapshot.pages.count),
              snapshot.pages.indices.contains(snapshot.current),
              snapshot.attachments == nil || snapshot.attachments?.count == snapshot.pages.count
        else { throw CocoaError(.fileReadCorruptFile) }

        let notebook = Notebook(id: UUID(), title: snapshot.title, pageCount: snapshot.pages.count,
                                paper: snapshot.paper)
        let encoder = JSONEncoder()
        let encoded = try snapshot.pages.map { try encoder.encode($0) }
        let cover = try snapshot.cover.map { try encoder.encode($0) }
        var writtenKeys: [String] = []
        do {
            for (number, attachment) in (snapshot.attachments ?? []).enumerated() {
                guard let attachment else { continue }
                guard UIImage(data: attachment) != nil else { throw CocoaError(.fileReadCorruptFile) }
                let key = notebook.storageKey(for: number)
                try storage.writeAttachment(attachment, for: key)
                writtenKeys.append(key)
            }
        } catch {
            for key in writtenKeys { storage.removePage(key) }
            throw error
        }

        for (number, data) in encoded.enumerated() {
            storage.writeStrokeData(data, for: notebook.storageKey(for: number))
        }
        if let cover { storage.writeStrokeData(cover, for: notebook.coverStorageKey) }
        return (notebook, snapshot.current)
    }

    private func shareFile(_ data: Data, name: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }
}

// Keep these field names compatible with existing JSON backups.
private struct NotebookBackup: Codable {
    var version = 1
    let title: String
    let paper: PaperStyle
    let current: Int
    let pages: [[Stroke]]
    var attachments: [Data?]? = nil
    var cover: [Stroke]? = nil
}
