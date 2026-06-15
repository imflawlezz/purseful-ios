import Foundation
import NaturalLanguage

struct ReceiptParseResult {
    var merchant: String?
    var total: Decimal?
    var date: Date?
    var suggestedCategory: String?
    var confidence: Double
    var rawText: String
    var nip: String?
}

enum ReceiptParser {
    private static let totalKeywords = [
        "TOTAL", "SUMA", "RAZEM", "DO ZAPŁATY", "AMOUNT DUE", "GRAND TOTAL", "SUM"
    ]

    private static let merchantChains: [String: String] = [
        "biedronka": "Groceries",
        "lidl": "Groceries",
        "kaufland": "Groceries",
        "carrefour": "Groceries",
        "orlen": "Fuel",
        "bp": "Fuel",
        "shell": "Fuel",
        "mcdonald": "Restaurants",
        "kfc": "Restaurants",
        "starbucks": "Coffee",
        "zabka": "Groceries",
        "rossmann": "Pharmacy",
        "allegro": "Shopping"
    ]

    static func parse(text: String) -> ReceiptParseResult {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let total = extractTotal(from: lines)
        let date = extractDate(from: text)
        let merchant = extractMerchant(from: lines)
        let nip = extractNIP(from: text)
        let category = merchant.flatMap { suggestCategory(for: $0) }

        var confidence = 0.3
        if total != nil { confidence += 0.3 }
        if date != nil { confidence += 0.2 }
        if merchant != nil { confidence += 0.15 }
        if category != nil { confidence += 0.05 }

        return ReceiptParseResult(
            merchant: merchant,
            total: total,
            date: date,
            suggestedCategory: category,
            confidence: min(confidence, 1),
            rawText: text,
            nip: nip
        )
    }

    private static func extractTotal(from lines: [String]) -> Decimal? {
        var candidates: [Decimal] = []

        for line in lines {
            let upper = line.uppercased()
            if totalKeywords.contains(where: { upper.contains($0) }) {
                if let amount = largestAmount(in: line) {
                    candidates.append(amount)
                }
            }
        }

        if candidates.isEmpty {
            for line in lines {
                if let amount = largestAmount(in: line) {
                    candidates.append(amount)
                }
            }
        }

        return candidates.max()
    }

    private static func largestAmount(in line: String) -> Decimal? {
        let pattern = #"(?<![\d])(\d{1,3}(?:[.,\s]\d{3})*(?:[.,]\d{2})|\d+[.,]\d{2})(?![\d])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(line.startIndex..., in: line)
        let matches = regex.matches(in: line, range: range)
        let amounts = matches.compactMap { match -> Decimal? in
            guard let r = Range(match.range(at: 1), in: line) else { return nil }
            let raw = String(line[r]).replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")
            return Decimal(string: raw)
        }
        return amounts.max()
    }

    private static func extractDate(from text: String) -> Date? {
        let patterns = [
            #"\b(\d{2})[./-](\d{2})[./-](\d{4})\b"#,
            #"\b(\d{4})[./-](\d{2})[./-](\d{2})\b"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range),
               let r = Range(match.range, in: text) {
                let dateString = String(text[r])
                for format in ["dd.MM.yyyy", "dd/MM/yyyy", "yyyy-MM-dd", "dd-MM-yyyy"] {
                    let formatter = DateFormatter()
                    formatter.dateFormat = format
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }
            }
        }
        return nil
    }

    private static func extractMerchant(from lines: [String]) -> String? {
        let headerLines = Array(lines.prefix(3))
        let tagger = NLTagger(tagSchemes: [.nameType])
        for line in headerLines where !line.localizedCaseInsensitiveContains("NIP") {
            tagger.string = line
            var orgName: String?
            tagger.enumerateTags(in: line.startIndex..<line.endIndex, unit: .word, scheme: .nameType) { tag, range in
                if tag == .organizationName {
                    orgName = String(line[range])
                }
                return true
            }
            if let orgName, !orgName.isEmpty { return orgName }
            if line.count > 2 { return line }
        }
        return headerLines.first
    }

    private static func extractNIP(from text: String) -> String? {
        let pattern = #"\bNIP[:\s]*(\d{3}[-\s]?\d{3}[-\s]?\d{2}[-\s]?\d{2}|\d{10})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    private static func suggestCategory(for merchant: String) -> String? {
        let lower = merchant.lowercased()
        for (chain, category) in merchantChains {
            if lower.contains(chain) { return category }
        }
        return nil
    }
}
