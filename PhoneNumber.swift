import Foundation

enum PhoneNumber {
    enum Invalid: Error { case format }

    // Require explicit + or 00 for international numbers. Bare input is Hong Kong local.
    static func normalize(_ input: String) throws -> Int64 {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet(charactersIn: "+0123456789 ()-\t\r\n")
        guard !trimmed.isEmpty, trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw Invalid.format
        }
        let compact = trimmed.filter { !" ()-\t\r\n".contains($0) }
        let digits: String
        if compact.hasPrefix("+") {
            digits = String(compact.dropFirst())
        } else if compact.hasPrefix("00") {
            digits = String(compact.dropFirst(2))
        } else {
            guard compact.count == 8, compact.first != "0" else { throw Invalid.format }
            digits = "852" + compact
        }
        guard (7...15).contains(digits.count), digits.first != "0",
              digits.allSatisfy({ $0 >= "0" && $0 <= "9" }),
              let value = Int64(digits), value > 0 else { throw Invalid.format }
        if digits.hasPrefix("852") {
            guard digits.count == 11, digits.dropFirst(3).first != "0" else { throw Invalid.format }
        }
        return value
    }
}
