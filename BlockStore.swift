import Foundation

enum BlockStore {
    // Must match both provisioning profiles and the signing tool's App Group configuration.
    static let groupID = "group.com.kakorochan.HKCallBlocker"
    struct Snapshot: Codable {
        let revision: UUID
        let numbers: [Int64]
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
            return Snapshot(revision: UUID(), numbers: [])
        }
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
        guard snapshot.numbers == Array(Set(snapshot.numbers)).sorted(),
              snapshot.numbers.allSatisfy({ $0 > 0 && $0 < 1_000_000_000_000_000 }) else {
            throw StoreError.corruptData
        }
        return snapshot
    }

    @discardableResult static func write(_ numbers: [Int64]) throws -> Snapshot {
        let snapshot = Snapshot(revision: UUID(), numbers: Array(Set(numbers)).sorted())
        try JSONEncoder().encode(snapshot).write(to: file("blocked.json"), options: .atomic)
        return snapshot
    }
}
