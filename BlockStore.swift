import Foundation

enum BlockStore {
    // Must match both provisioning profiles and the signing tool's App Group configuration.
    static let groupID = "group.com.kakorochan.HKCallBlocker"
    struct Entry: Codable, Identifiable, Equatable {
        var id: Int64 { number }
        let number: Int64
        var name: String
    }
    struct Snapshot: Codable {
        let revision: UUID
        let entries: [Entry]

        // Decode the first release's number-only list without losing saved blocks.
        init(revision: UUID, entries: [Entry]) {
            self.revision = revision
            self.entries = entries
        }
        private enum CodingKeys: String, CodingKey { case revision, entries, numbers }
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            revision = try values.decode(UUID.self, forKey: .revision)
            if let stored = try values.decodeIfPresent([Entry].self, forKey: .entries) {
                entries = stored
            } else {
                entries = try values.decode([Int64].self, forKey: .numbers).map { Entry(number: $0, name: "") }
            }
        }
        func encode(to encoder: Encoder) throws {
            var values = encoder.container(keyedBy: CodingKeys.self)
            try values.encode(revision, forKey: .revision)
            try values.encode(entries, forKey: .entries)
        }
    }
    enum StoreError: Error { case missingGroup, corruptData }

    static func file(_ name: String) throws -> URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupID
        ) else { throw StoreError.missingGroup }
        return container.appendingPathComponent(name)
    }

    static func read() throws -> Snapshot {
        let url = try file("blocked.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return Snapshot(revision: UUID(), entries: [])
        }
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
        let numbers = snapshot.entries.map(\.number)
        guard numbers == Array(Set(numbers)).sorted(),
              numbers.allSatisfy({ $0 > 0 && $0 < 1_000_000_000_000_000 }),
              snapshot.entries.allSatisfy({ $0.name.count <= 80 }) else {
            throw StoreError.corruptData
        }
        return snapshot
    }

    @discardableResult static func write(_ entries: [Entry]) throws -> Snapshot {
        let numbers = entries.map(\.number)
        guard numbers.count == Set(numbers).count,
              entries.allSatisfy({ $0.name.count <= 80 }) else { throw StoreError.corruptData }
        let snapshot = Snapshot(revision: UUID(), entries: entries.sorted { $0.number < $1.number })
        try JSONEncoder().encode(snapshot).write(to: file("blocked.json"), options: .atomic)
        return snapshot
    }
}
