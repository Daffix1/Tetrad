import Foundation

struct Notebook: Codable, Identifiable {
    static let maximumPageCount = 86

    let id: UUID
    var title: String
    var pageCount = 3

    var paper: PaperStyle? = nil
    var pageIDs: [String]? = nil

    var coverStorageKey: String { "notebook.\(id.uuidString).cover" }

    var paperStyle: PaperStyle { paper ?? .ruled }

    // Earlier versions used page numbers as storage IDs.
    var leaves: [String] { pageIDs ?? (0..<pageCount).map(String.init) }

    mutating func setLeaves(_ leaves: [String]) {
        pageIDs = leaves
        pageCount = leaves.count
    }

    func storageKey(for page: Int) -> String {
        storageKey(forLeaf: leaves[page])
    }

    func storageKey(forLeaf leaf: String) -> String {
        "notebook.\(id.uuidString).page.\(leaf)"
    }
}

enum PaperStyle: String, Codable, CaseIterable {
    case ruled = "В линейку"
    case grid = "В клетку"
    case dots = "В точку"
    case blank = "Чистая"
}
