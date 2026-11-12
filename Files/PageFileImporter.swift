import ImageIO
import PDFKit
import UIKit
import UniformTypeIdentifiers

struct PageFileImporter {
    var storage = PageStorage.standard

    func appendingPages(from urls: [URL], to notebook: Notebook) throws -> Notebook {
        var leaves = notebook.leaves
        var writtenKeys: [String] = []
        do {
            for url in urls {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }

                let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
                let isPDF = url.pathExtension.lowercased() == "pdf" || type?.conforms(to: .pdf) == true
                let pdf = isPDF ? PDFDocument(url: url) : nil
                let count = isPDF ? (pdf?.pageCount ?? 0) : 1
                guard count > 0, pdf?.isLocked != true else { throw PageImportError.unreadable }
                guard count <= Notebook.maximumPageCount - leaves.count else { throw PageImportError.limit }

                for number in 0..<count {
                    let data = try autoreleasepool {
                        try encode(url: url, pdf: pdf, number: number)
                    }
                    let leaf = UUID().uuidString
                    let key = notebook.storageKey(forLeaf: leaf)
                    try storage.writeAttachment(data, for: key)
                    writtenKeys.append(key)
                    leaves.append(leaf)
                }
            }
        } catch {
            for key in writtenKeys { storage.removePage(key) }
            throw error
        }

        var updated = notebook
        updated.setLeaves(leaves)
        return updated
    }

    private func encode(url: URL, pdf: PDFDocument?, number: Int) throws -> Data {
        if let pdf {
            guard let page = pdf.page(at: number) else { throw PageImportError.unreadable }
            let bounds = page.pageRef?.getBoxRect(.cropBox) ?? page.bounds(for: .cropBox)
            let sideways = abs(page.rotation % 180) == 90
            let size = sideways ? CGSize(width: bounds.height, height: bounds.width) : bounds.size
            guard size.width > 0, size.height > 0 else { throw PageImportError.unreadable }
            let target = PageLayout.fit(size).size
            let image = page.thumbnail(of: CGSize(width: target.width * 2, height: target.height * 2),
                                       for: .cropBox)
            guard let data = image.pngData() else { throw PageImportError.unreadable }
            return data
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1760
              ] as CFDictionary),
              let data = UIImage(cgImage: thumbnail).pngData() else {
            throw PageImportError.unreadable
        }
        return data
    }
}

private enum PageImportError: LocalizedError {
    case limit
    case unreadable

    var errorDescription: String? {
        switch self {
        case .limit: "В тетради может быть до 86 листов. Выбери меньше страниц."
        case .unreadable: "Не удалось прочитать файл. Если PDF защищён паролем, сначала сними защиту."
        }
    }
}

