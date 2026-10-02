import Foundation

let valid: [(String, Int64)] = [
    ("9123 4567", 85291234567),
    ("+852 9123-4567", 85291234567),
    ("00852 91234567", 85291234567),
    ("+86 13800138000", 8613800138000),
    ("+1 (415) 555-0123", 14155550123),
    ("23456789", 85223456789)
]
for (input, expected) in valid {
    let actual = try PhoneNumber.normalize(input)
    precondition(actual == expected, "Incorrect normalization: \(input)")
}
for input in ["", "+", "123", "85291234567", "09123456", "+852123", "+085291234567", "91234567abc", "++85291234567", "９１２３４５６７", "+1234567890123456"] {
    do {
        _ = try PhoneNumber.normalize(input)
        fatalError("Accepted invalid input: \(input)")
    } catch PhoneNumber.Invalid.format { }
}
let equivalent = try ["91234567", "+85291234567", "0085291234567"].map(PhoneNumber.normalize)
precondition(Set(equivalent).count == 1)
let legacyJSON = #"{"revision":"00000000-0000-0000-0000-000000000001","numbers":[85291234567]}"#
let migrated = try JSONDecoder().decode(BlockStore.Snapshot.self, from: Data(legacyJSON.utf8))
precondition(migrated.entries == [BlockStore.Entry(number: 85291234567, name: "")])
let named = BlockStore.Snapshot(revision: UUID(), entries: [BlockStore.Entry(number: 85291234567, name: "Spam caller")])
let roundTrip = try JSONDecoder().decode(BlockStore.Snapshot.self, from: JSONEncoder().encode(named))
precondition(roundTrip.entries == named.entries)
print("Phone normalization checks passed.")
