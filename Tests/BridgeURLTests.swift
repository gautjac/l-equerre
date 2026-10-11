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

    // MARK: snap (Le Verbe's three choices, and the rest)

    func testSnapShortNames() {
        XCTAssertEqual(parse("x-equerre://snap?zone=left"), .snap(zone: .leftHalf, app: nil))
        XCTAssertEqual(parse("x-equerre://snap?zone=right&app=com.apple.Safari"), .snap(zone: .rightHalf, app: "com.apple.Safari"))
        XCTAssertEqual(parse("x-equerre://snap?zone=almost"), .snap(zone: .almostMaximize, app: nil))
        XCTAssertEqual(parse("x-equerre://snap?zone=Full"), .snap(zone: .maximize, app: nil), "case never matters")
        XCTAssertEqual(parse("X-EQUERRE://SNAP?ZONE=gauche"), .snap(zone: .leftHalf, app: nil))
    }

    func testSnapAcceptsAnyFixedZoneByItsName() {
        XCTAssertEqual(parse("x-equerre://snap?zone=topLeft"), .snap(zone: .topLeft, app: nil))
        XCTAssertEqual(parse("x-equerre://snap?zone=leftTwoThirds"), .snap(zone: .leftTwoThirds, app: nil))
        XCTAssertEqual(parse("x-equerre://snap?zone=center"), .snap(zone: .center, app: nil))
    }

    func testSnapRefusesWhatIsNotAZone() {
        XCTAssertNil(parse("x-equerre://snap"), "no zone")
        XCTAssertNil(parse("x-equerre://snap?zone="))
        XCTAssertNil(parse("x-equerre://snap?zone=banana"))
        for verb in ["cycleLeft", "cycleRight", "cycleUp", "cycleDown", "sideBySide"] {
            XCTAssertNil(parse("x-equerre://snap?zone=\(verb)"), "\(verb) needs key presses or two windows, not a URL")
        }
    }

    func testSnapAppIsOptionalAndTrimmed() {
        XCTAssertEqual(parse("x-equerre://snap?zone=left&app="), .snap(zone: .leftHalf, app: nil))
        XCTAssertEqual(parse("x-equerre://snap?zone=left&app=%20com.apple.Notes%20"), .snap(zone: .leftHalf, app: "com.apple.Notes"))
    }

    func testTheThreeZonesAreWhatTheirNamesSay() {
        XCTAssertEqual(SnapAction.leftHalf.fraction, FractionRect(0, 0, 0.5, 1))
        XCTAssertEqual(SnapAction.rightHalf.fraction, FractionRect(0.5, 0, 0.5, 1))
        XCTAssertEqual(SnapAction.almostMaximize.fraction, FractionRect(0.04, 0.04, 0.92, 0.92))
    }
}
