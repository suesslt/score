import XCTest
@testable import Score

final class HomeTimeZoneTests: XCTestCase {

    func testHomeTimeZoneIsZurich() {
        XCTAssertEqual(TimeZone.home.identifier, "Europe/Zurich")
        XCTAssertEqual(Calendar.home.timeZone.identifier, "Europe/Zurich")
        XCTAssertEqual(Calendar.home.identifier, .gregorian)
    }

    func testHomeCalendarAnchorsDayBoundaries() {
        // 2026-06-15 22:30 UTC = 2026-06-16 00:30 in Zürich (Sommerzeit +2)
        let utc = TimeZone(identifier: "UTC")!
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = utc
        let date = utcCalendar.date(from: DateComponents(year: 2026, month: 6, day: 15,
                                                         hour: 22, minute: 30))!
        let components = Calendar.home.dateComponents([.day, .hour], from: date)
        XCTAssertEqual(components.day, 16)
        XCTAssertEqual(components.hour, 0)
    }
}
