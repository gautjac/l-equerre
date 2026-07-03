import XCTest
@testable import LEquerre

/// Tests for the `x-equerre://` remote-control contract — pure URL parsing,
/// no AppKit, no windows, no Accessibility permission. This is the bridge that
/// lets La Régie fire a saved disposition by name.
final class BridgeURLTests: XCTestCase {

    private func parse(_ s: String) -> BridgeCommand? {
        guard let url = URL(string: s) else { XCTFail("bad test URL: \(s)"); return nil }
        return BridgeURL.parse(url)
    }

    // MARK: apply

    func testApplyExtractsName() {
        XCTAssertEqual(parse("x-equerre://apply?name=Montage"), .apply(name: "Montage"))
    }

    func testApplyDecodesPercentEncoding() {
        // "Salle de montage" → spaces arrive percent-encoded.
        XCTAssertEqual(parse("x-equerre://apply?name=Salle%20de%20montage"),
                       .apply(name: "Salle de montage"))
    }

    func testApplyTrimsSurroundingWhitespace() {
        XCTAssertEqual(parse("x-equerre://apply?name=%20Montage%20"),
                       .apply(name: "Montage"))
    }

    func testApplyToleratesExtraQueryItems() {
        // %C3%89criture → "Écriture" — accents survive the round-trip.
        XCTAssertEqual(parse("x-equerre://apply?foo=bar&name=%C3%89criture"),
                       .apply(name: "Écriture"))
    }

    func testSchemeAndHostAreCaseInsensitive() {
        XCTAssertEqual(parse("X-EQUERRE://APPLY?name=Montage"), .apply(name: "Montage"))
    }

    func testNameKeyIsCaseInsensitive() {
        XCTAssertEqual(parse("x-equerre://apply?Name=Montage"), .apply(name: "Montage"))
    }

    // MARK: rejection

    func testWrongSchemeIsRejected() {
        XCTAssertNil(parse("https://apply?name=Montage"))
        XCTAssertNil(parse("x-regie://apply?name=Montage"))
    }

    func testUnknownVerbIsRejected() {
        XCTAssertNil(parse("x-equerre://capture?name=Montage"))
    }

    func testMissingNameIsRejected() {
        XCTAssertNil(parse("x-equerre://apply"))
        XCTAssertNil(parse("x-equerre://apply?other=1"))
    }

    func testEmptyOrWhitespaceNameIsRejected() {
        XCTAssertNil(parse("x-equerre://apply?name="))
        XCTAssertNil(parse("x-equerre://apply?name=%20%20"))
    }
}
