import Foundation

struct PageStorage {
    static let standard = PageStorage(
        defaults: .standard,
        attachmentsDirectory: URL.applicationSupportDirectory
            .appendingPathComponent("ImportedPages", isDirectory: true)
    )

    let defaults: UserDefaults
    let attachmentsDirectory: URL

    func loadStrokes(_ key: String) -> [Stroke] {
        guard let data = defaults.data(forKey: key) else { return [] }
        let decoder = JSONDecoder()
        if let strokes = try? decoder.decode([Stroke].self, from: data) {
            return strokes
        }

        // The first version stored only the points of each stroke.
        let points = (try? decoder.decode([[Point]].self, from: data)) ?? []
        return points.map { Stroke(points: $0, brush: Brush()) }
    }

    func saveStrokes(_ strokes: [Stroke], for key: String) throws {
        try writeStrokeData(JSONEncoder().encode(strokes), for: key)
    }

    func writeStrokeData(_ data: Data, for key: String) {
        defaults.set(data, forKey: key)
    }

    func attachmentURL(for key: String) -> URL {
        attachmentsDirectory.appendingPathComponent(key + ".png")
    }

    func writeAttachment(_ data: Data, for key: String) throws {
        try FileManager.default.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)
        try data.write(to: attachmentURL(for: key), options: .atomic)
    }

    func removePage(_ key: String) {
        defaults.removeObject(forKey: key)
        try? FileManager.default.removeItem(at: attachmentURL(for: key))
    }
}
