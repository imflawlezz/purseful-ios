import XCTest
@testable import purseful_ios

final class ReceiptParserTests: XCTestCase {
    func testParsesPolishTotalKeyword() {
        let text = """
        BIEDRONKA
        ul. Testowa 1
        PARAGON FISKALNY
        CHLEB           4,99
        SUMA            4,99
        """
        let result = ReceiptParser.parse(text: text)
        XCTAssertEqual(result.total, Decimal(string: "4.99"))
        XCTAssertEqual(result.merchant, "Biedronka")
        XCTAssertEqual(result.suggestedCategory, "Groceries")
    }

    func testParsesDate() {
        let text = "Sklep\n12.03.2024\nTOTAL 19,50"
        let result = ReceiptParser.parse(text: text)
        XCTAssertNotNil(result.date)
        XCTAssertEqual(result.total, Decimal(string: "19.50"))
    }

    func testSuggestsGroceriesForBiedronka() {
        let result = ReceiptParser.parse(text: "BIEDRONKA\nSUMA 10,00")
        XCTAssertEqual(result.suggestedCategory, "Groceries")
        XCTAssertEqual(result.total, Decimal(string: "10.00"))
    }

    func testParsesViveFiscalReceipt() {
        let text = """
        VIVE Profit
        VIVE Textile Recycling Sp. z o.o.
        02-220 Warszawa, ul. Łopuszańska 22
        Adres korespondencyjny: 25-663 Kielce, ul. Karola Olszewskiego 6
        SKLEP FIRMOWY VIVE Profit
        21-500 Biała Podlaska, ul. Sidorska 102
        NIP: 657-008-10-33
        PARAGON FISKALNY
        Podkoszulki męskie + koszulki termiczn A 1 szt*14.99 14.99A
        Podkoszulki na ramiączkach męskie A 1 szt*14.99 14.99A
        Podkoszulki męskie + koszulki termiczn A 1 szt*14.99 14.99A
        OBNIŻKA -10.00A
        Suma obniżek: 10.00
        Sprzedaż opodatkowana A: 34.97
        Kwota PTU A 23% 6.54
        SUMA PTU 6.54
        SUMA: PLN 34.97
        DO ZAPŁATY: 34.97
        ROZLICZENIE PŁATNOŚCI
        Gotówka: 35.00
        Reszta (Gotówka PLN): 0.03
        F116723 #2 12 23-07-2026 10:27
        Nr transakcji: 133397
        """
        let result = ReceiptParser.parse(text: text)
        XCTAssertEqual(result.total, Decimal(string: "34.97"))
        XCTAssertEqual(result.merchant, "VIVE Profit")
        XCTAssertEqual(result.suggestedCategory, "Shopping")
        XCTAssertEqual(result.nip, "6570081033")
        XCTAssertNotNil(result.date)

        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day], from: result.date!)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 7)
        XCTAssertEqual(comps.day, 23)
    }

    func testParsesPepcoFiscalReceipt() {
        let text = """
        pepco
        Pepco Poland Sp. z o.o.
        ul. Strzeszyńska 73A, 60-479 Poznań
        Nr rej.: 000007930
        PEPCO
        21-500 Biała Podlaska
        Brzeska 27
        NIP 782-21-31-157
        nr wydr. 025793/0108
        PARAGON FISKALNY
        63624701 NARZUTA FROTA HAFT 2_ON 1 * 100,00 100,00 A
        63575601 Lampa złota regular_ONE 1 * 65,00 65,00 A
        63447204 Piżama męska kr/ks b_XX 1 * 12,00 12,00 A
        Sprzed. opod. PTU A 177,00
        Kwota PTU A 23,00% 33,10
        SUMA PTU 33,10
        SUMA PLN 177,00
        ROZLICZENIE PŁATNOŚCI
        Płatność 207,00
        Wpłacono razem 207,00
        RESZTA Gotówka 30,00
        000129/0108 #003 1062848
        2026-07-22 19:03
        Gotówka PLN 207,00
        Sklep: 110262 Nr transakcji: 15429 Kasa: 3
        """
        let result = ReceiptParser.parse(text: text)
        XCTAssertEqual(result.total, Decimal(string: "177.00"))
        XCTAssertEqual(result.merchant, "Pepco")
        XCTAssertEqual(result.suggestedCategory, "Shopping")
        XCTAssertEqual(result.nip, "7822131157")
        XCTAssertNotNil(result.date)

        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day], from: result.date!)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 7)
        XCTAssertEqual(comps.day, 22)
    }

    func testIgnoresSumaPTUWhenOnlyVATPresentBeforeGrandTotalOnNextLine() {
        let text = """
        Sklep Testowy
        PARAGON FISKALNY
        SUMA PTU
        12,30
        SUMA PLN
        65,90
        """
        let result = ReceiptParser.parse(text: text)
        XCTAssertEqual(result.total, Decimal(string: "65.90"))
    }

    func testPrefersDoZaplatyOverCashTendered() {
        let text = """
        Lidl
        PARAGON FISKALNY
        DO ZAPŁATY 41,20
        Gotówka 50,00
        Reszta 8,80
        """
        let result = ReceiptParser.parse(text: text)
        XCTAssertEqual(result.total, Decimal(string: "41.20"))
        XCTAssertEqual(result.merchant, "Lidl")
    }
}
