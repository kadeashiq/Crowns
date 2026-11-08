import Foundation

/// The last few extractions, kept in the App Group so the app can show what
/// the extension saw. When a site comes out wrong, export the entry: the
/// snapshot JSON drops straight into CrownsTests/Fixtures as a regression test.
struct DiagnosticEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date()
    var url: String?
    var steps: [String]
    var draft: ListingDraft
    var photoCount: Int
    var saved: Bool
    var snapshotJSON: String?
}

enum DiagnosticsLog {
    static let keep = 20

    static var directory: URL? {
        guard let base = AppGroup.containerURL else { return nil }
        let dir = base.appending(path: "Diagnostics", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func record(_ entry: DiagnosticEntry) {
        guard let dir = directory else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entry) else { return }
        let name = "\(Int(entry.date.timeIntervalSince1970))-\(entry.id.uuidString.prefix(8)).json"
        try? data.write(to: dir.appending(path: name), options: .atomic)
        prune(dir)
    }

    struct StoredEntry: Identifiable, Hashable {
        var entry: DiagnosticEntry
        var file: URL
        var id: UUID { entry.id }
    }

    static func entries() -> [StoredEntry] {
        guard let dir = directory,
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return files.filter { $0.pathExtension == "json" }
            .compactMap { file in
                guard let data = try? Data(contentsOf: file), let entry = try? decoder.decode(DiagnosticEntry.self, from: data) else { return nil }
                return StoredEntry(entry: entry, file: file)
            }
            .sorted { $0.entry.date > $1.entry.date }
    }

    private static func prune(_ dir: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        let sorted = files.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
        for stale in sorted.dropFirst(keep) {
            try? FileManager.default.removeItem(at: stale)
        }
    }
}
