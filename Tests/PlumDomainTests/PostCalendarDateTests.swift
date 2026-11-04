import Foundation
import XCTest
@testable import PlumDomain

final class PostCalendarDateTests: XCTestCase {
    func testChosenDayEastOfUTCDoesNotMoveToPreviousDay() throws {
        let instant = try XCTUnwrap(ISO8601DateFormatter().date(from: "2020-01-01T10:30:00Z"))
        let zone = try XCTUnwrap(TimeZone(secondsFromGMT: 14 * 3600))
        XCTAssertEqual(PostCalendarDate.string(from: instant, timeZone: zone), "2020-01-02")
    }

    func testChosenDayWestOfUTCDoesNotMoveToNextDay() throws {
        let instant = try XCTUnwrap(ISO8601DateFormatter().date(from: "2020-01-02T02:00:00Z"))
        let zone = try XCTUnwrap(TimeZone(secondsFromGMT: -8 * 3600))
        XCTAssertEqual(PostCalendarDate.string(from: instant, timeZone: zone), "2020-01-01")
    }

    func testSavedBackdatedAndLeapDaysRemainCalendarDays() throws {
        for offset in [-8 * 3600, 14 * 3600] {
            let zone = try XCTUnwrap(TimeZone(secondsFromGMT: offset))
            for day in ["2020-01-02", "2024-02-29"] {
                let parsed = try XCTUnwrap(PostCalendarDate.date(from: day, timeZone: zone))
                XCTAssertEqual(PostCalendarDate.string(from: parsed, timeZone: zone), day)
            }
        }
    }

    func testInvalidSavedDateCanFallBackToCreationDate() {
        XCTAssertNil(PostCalendarDate.date(from: "2024-02-30"))
        XCTAssertNil(PostCalendarDate.date(from: "not a date"))
    }
}
