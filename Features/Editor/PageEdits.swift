import Combine

@MainActor
final class PageEdits: ObservableObject {
    private let storage: PageStorage

    init(storage: PageStorage = .standard) {
        self.storage = storage
    }

    @Published private(set) var revision = 0
    private var undone: [String: [Stroke]] = [:]
    private var counts: [String: Int] = [:]
    @Published private var drawing: Set<String> = []

    func canUndo(_ key: String) -> Bool {
        !drawing.contains(key) && (counts[key] ?? storage.loadStrokes(key).count) > 0
    }

    func canRedo(_ key: String) -> Bool {
        !drawing.contains(key) && undone[key]?.isEmpty == false
    }

    func setDrawing(_ active: Bool, for key: String) {
        if active { drawing.insert(key) } else { drawing.remove(key) }
    }

    func commit(_ stroke: Stroke, to key: String) {
        var strokes = storage.loadStrokes(key)
        strokes.append(stroke)
        undone.removeValue(forKey: key)
        save(strokes, for: key)
    }

    func undo(_ key: String) {
        guard canUndo(key) else { return }
        var strokes = storage.loadStrokes(key)
        guard let last = strokes.popLast() else { return }
        undone[key, default: []].append(last)
        save(strokes, for: key)
    }

    func redo(_ key: String) {
        guard canRedo(key), let last = undone[key]?.popLast() else { return }
        var strokes = storage.loadStrokes(key)
        strokes.append(last)
        save(strokes, for: key)
    }

    func forget(_ key: String) {
        undone.removeValue(forKey: key)
        counts.removeValue(forKey: key)
        drawing.remove(key)
    }

    private func save(_ strokes: [Stroke], for key: String) {
        guard (try? storage.saveStrokes(strokes, for: key)) != nil else { return }
        counts[key] = strokes.count
        revision += 1
    }
}
