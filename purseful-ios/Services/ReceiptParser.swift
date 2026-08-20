import Foundation
import NaturalLanguage

nonisolated struct ReceiptParseResult: Sendable {
    var merchant: String?
    var total: Decimal?
    var date: Date?
    var suggestedCategory: String?
    var confidence: Double
    var rawText: String
    var nip: String?
}

nonisolated enum ReceiptParser {
    private static let primaryTotalKeywords = [
        "DO ZAPŁATY",
        "DO ZAPLATY",
        "GRAND TOTAL",
        "AMOUNT DUE",
        "SUMA PLN",
        "SUMA: PLN",
        "TOTAL PLN",
        "RAZEM PLN",
        "DO ZAPŁATY PLN",
    ]

    private static let secondaryTotalKeywords = [
        "TOTAL", "SUMA", "RAZEM", "SUM"
    ]

    private static let totalNoiseKeywords = [
        "PTU", "VAT", "PODATEK",
        "OBNIŻ", "OBNIZ", "RABAT", "DISCOUNT",
        "OPODATKOWAN", "OPOD. PTU", "OPOD PTU", "SPRZED",
        "GOTÓWKA", "GOTOWKA", "RESZTA", "WPŁACONO", "WPLACONO",
        "PŁATNOŚĆ", "PLATNOSC", "PŁATNOSC", "PLATNOŚĆ",
        "ROZLICZENIE", "KARTA", "BLIK",
    ]

    private static let skipMerchantKeywords = [
        "NIP", "PARAGON", "FISKALNY", "UL.", "UL ", "SP. Z", "SP Z",
        "ADRES", "KORESPONDENCYJNY", "NR REJ", "NR WYD", "WWW.",
        "SKLEP FIRMOWY", "TEL.", "FAX",
    ]

    private static let merchantChains: [String: String] = [
        "biedronka": "Groceries",
        "lidl": "Groceries",
        "kaufland": "Groceries",
        "carrefour": "Groceries",
        "auchan": "Groceries",
        "netto": "Groceries",
        "dino": "Groceries",
        "orlen": "Fuel",
        "bp": "Fuel",
        "shell": "Fuel",
        "circle k": "Fuel",
        "mcdonald": "Restaurants",
        "kfc": "Restaurants",
        "starbucks": "Coffee",
        "żabka": "Groceries",
        "zabka": "Groceries",
        "rossmann": "Pharmacy",
        "hebe": "Pharmacy",
        "allegro": "Shopping",
        "pepco": "Shopping",
        "vive": "Shopping",
        "reserved": "Shopping",
        "sinsay": "Shopping",
        "house": "Shopping",
        "cropp": "Shopping",
        "media markt": "Shopping",
        "mediaexpert": "Shopping",
        "media expert": "Shopping",
        "rtv euro": "Shopping",
        "ikea": "Shopping",
        "action": "Shopping",
        "dealz": "Shopping",
        "primark": "Shopping",
        "hm ": "Shopping",
        "h&m": "Shopping",
        "zara": "Shopping",
    ]

    static func parse(text: String) -> ReceiptParseResult {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
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
        if let amount = firstAmount(
            in: lines,
            matchingAnyOf: primaryTotalKeywords,
            excludingNoise: true
        ) {
            return amount
        }

        if let amount = firstAmount(
            in: lines,
            matchingAnyOf: secondaryTotalKeywords,
            excludingNoise: true
        ) {
            return amount
        }

        var candidates: [Decimal] = []
        for line in lines where !isNoiseTotalLine(line) && !looksLikeLineItem(line) {
            if let amount = amounts(in: line).last {
                candidates.append(amount)
            }
        }
        return candidates.max()
    }

    private static func firstAmount(
        in lines: [String],
        matchingAnyOf keywords: [String],
        excludingNoise: Bool
    ) -> Decimal? {
        let normalizedKeywords = keywords.map(normalize)
        for (index, line) in lines.enumerated() {
            let upper = normalize(line)
            guard normalizedKeywords.contains(where: { upper.contains($0) }) else { continue }
            if excludingNoise, isNoiseTotalLine(line) { continue }

            if let amount = preferredAmount(on: line) {
                return amount
            }
            if index + 1 < lines.count, let amount = preferredAmount(on: lines[index + 1]) {
                return amount
            }
        }
        return nil
    }

    private static func isNoiseTotalLine(_ line: String) -> Bool {
        let upper = normalize(line)
        return totalNoiseKeywords.map(normalize).contains { upper.contains($0) }
    }

    private static func looksLikeLineItem(_ line: String) -> Bool {
        let upper = normalize(line)
        let primary = primaryTotalKeywords.map(normalize)
        let secondary = secondaryTotalKeywords.map(normalize)
        if upper.contains("SZT") || upper.contains("*") {
            return amounts(in: line).count >= 1 && !primary.contains(where: { upper.contains($0) })
        }
        if let regex = try? NSRegularExpression(pattern: #"\d[.,]\d{2}\s*[A-E]\b"#) {
            let range = NSRange(line.startIndex..., in: line)
            if regex.firstMatch(in: line, range: range) != nil,
               !secondary.contains(where: { upper.contains($0) }) {
                return true
            }
        }
        return false
    }

    private static func preferredAmount(on line: String) -> Decimal? {
        let values = amounts(in: line)
        return values.last
    }

    private static func amounts(in line: String) -> [Decimal] {
        let pattern = #"(?<![\d])(\d{1,3}(?:[.\s]\d{3})*,\d{2}|\d{1,3}(?:[,\s]\d{3})*\.\d{2}|\d+[.,]\d{2})(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(line.startIndex..., in: line)
        return regex.matches(in: line, range: range).compactMap { match -> Decimal? in
            guard let r = Range(match.range(at: 1), in: line) else { return nil }
            return parseAmount(String(line[r]))
        }
    }

    private static func parseAmount(_ raw: String) -> Decimal? {
        var cleaned = raw
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00a0}", with: "")

        if cleaned.contains(","), cleaned.contains(".") {
            if let lastComma = cleaned.lastIndex(of: ","),
               let lastDot = cleaned.lastIndex(of: ".") {
                if lastComma > lastDot {
                    cleaned = cleaned.replacingOccurrences(of: ".", with: "")
                    cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
                } else {
                    cleaned = cleaned.replacingOccurrences(of: ",", with: "")
                }
            }
        } else if cleaned.contains(",") {
            cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        }

        return Decimal(string: cleaned)
    }

    private static func extractDate(from text: String) -> Date? {
        let patterns: [(String, [String])] = [
            (#"\b(\d{2})[./-](\d{2})[./-](\d{4})\b"#, ["dd.MM.yyyy", "dd/MM/yyyy", "dd-MM-yyyy"]),
            (#"\b(\d{4})[./-](\d{2})[./-](\d{2})\b"#, ["yyyy-MM-dd", "yyyy.MM.dd", "yyyy/MM/dd"]),
        ]

        for (pattern, formats) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: range)
            for match in matches.reversed() {
                guard let r = Range(match.range, in: text) else { continue }
                let dateString = String(text[r])
                for format in formats {
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.timeZone = TimeZone.current
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
        let header = Array(lines.prefix(12))

        for line in header {
            let lower = line.lowercased()
            for chain in merchantChains.keys {
                if lower.contains(chain) {
                    return prettyMerchantName(for: chain, from: line)
                }
            }
        }

        let tagger = NLTagger(tagSchemes: [.nameType])
        for line in header where !shouldSkipMerchantLine(line) {
            tagger.string = line
            var orgName: String?
            tagger.enumerateTags(in: line.startIndex..<line.endIndex, unit: .word, scheme: .nameType) { tag, range in
                if tag == .organizationName {
                    orgName = String(line[range])
                }
                return true
            }
            if let orgName, orgName.count > 2 { return orgName }
        }

        return header.first { !shouldSkipMerchantLine($0) && $0.count > 2 }
    }

    private static func prettyMerchantName(for chain: String, from line: String) -> String {
        switch chain {
        case "vive":
            if line.localizedCaseInsensitiveContains("Profit") { return "VIVE Profit" }
            return "VIVE"
        case "pepco":
            return "Pepco"
        case "żabka", "zabka":
            return "Żabka"
        case "mcdonald":
            return "McDonald's"
        case "mediaexpert", "media expert":
            return "Media Expert"
        case "circle k":
            return "Circle K"
        case "rtv euro":
            return "RTV Euro AGD"
        case "h&m", "hm ":
            return "H&M"
        default:
            return chain.split(separator: " ")
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
    }

    private static func shouldSkipMerchantLine(_ line: String) -> Bool {
        let upper = normalize(line)
        if skipMerchantKeywords.map(normalize).contains(where: { upper.contains($0) }) { return true }
        if extractNIP(from: line) != nil { return true }
        let letters = line.filter(\.isLetter)
        return letters.count < 3
    }

    private static func extractNIP(from text: String) -> String? {
        let pattern = #"\bNIP[:\s]*([0-9][0-9\s-]{8,16}[0-9])"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        let digits = String(text[r]).filter(\.isNumber)
        return digits.count == 10 ? digits : nil
    }

    private static func suggestCategory(for merchant: String) -> String? {
        let lower = merchant.lowercased()
        for (chain, category) in merchantChains {
            if lower.contains(chain) { return category }
        }
        return nil
    }

    private static func normalize(_ line: String) -> String {
        line.uppercased()
            .replacingOccurrences(of: "Ł", with: "L")
            .replacingOccurrences(of: "Ą", with: "A")
            .replacingOccurrences(of: "Ę", with: "E")
            .replacingOccurrences(of: "Ó", with: "O")
            .replacingOccurrences(of: "Ś", with: "S")
            .replacingOccurrences(of: "Ż", with: "Z")
            .replacingOccurrences(of: "Ź", with: "Z")
            .replacingOccurrences(of: "Ć", with: "C")
            .replacingOccurrences(of: "Ń", with: "N")
    }
}
