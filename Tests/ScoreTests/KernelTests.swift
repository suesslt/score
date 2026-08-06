import XCTest
@testable import Score

final class DomainErrorTests: XCTestCase {

    func testNotFoundConvenienceOverloads() {
        let uuid = UUID()
        XCTAssertEqual(DomainError.notFound(entity: "Todo", id: uuid),
                       .notFound(entity: "Todo", id: uuid.uuidString))
        XCTAssertEqual(DomainError.notFound(entity: "User", id: 42),
                       .notFound(entity: "User", id: "42"))
    }

    func testBusinessRuleCodeOnlyFactory() {
        XCTAssertEqual(DomainError.businessRule("freemium.bookingLimit"),
                       .businessRule(code: "freemium.bookingLimit", message: ""))
    }

    func testCodableRoundTrip() throws {
        let errors: [DomainError] = [
            .notFound(entity: "Todo", id: "abc"),
            .validation(field: "title", message: "empty"),
            .conflict(message: "stale"),
            .businessRule(code: "x.y", message: "reason"),
            .unauthorized,
            .storage(message: "disk"),
            .transport(message: "offline"),
        ]
        let data = try JSONEncoder().encode(errors)
        let decoded = try JSONDecoder().decode([DomainError].self, from: data)
        XCTAssertEqual(decoded, errors)
    }
}

final class QueryingTests: XCTestCase {

    private enum TestField: String, Codable, Sendable, Equatable { case name, date }

    func testPaginationClamping() {
        XCTAssertEqual(Pagination(page: 0, size: 0).page, 1)
        XCTAssertEqual(Pagination(page: 0, size: 0).size, 1)
        XCTAssertEqual(Pagination(size: 500).size, PageLimits.maxSize)
        XCTAssertEqual(Pagination().page, 1)
        XCTAssertEqual(Pagination().size, 20)
        XCTAssertEqual(Pagination(page: 3, size: 20).offset, 40)
    }

    func testSortDefaultDirection() {
        XCTAssertEqual(Sort(field: TestField.name).direction, .asc)
        XCTAssertEqual(Sort(field: TestField.date, direction: .desc).direction, .desc)
    }

    func testPageCount() {
        XCTAssertEqual(Page<Int>(items: [], totalCount: 0, page: 1, size: 20).pageCount, 1)
        XCTAssertEqual(Page<Int>(items: [], totalCount: 41, page: 1, size: 20).pageCount, 3)
        XCTAssertEqual(Page<Int>(items: [], totalCount: 40, page: 1, size: 20).pageCount, 2)
        XCTAssertEqual(Page<Int>(items: [], totalCount: 5, page: 1, size: 0).pageCount, 1)
    }

    func testPageMapPreservesEnvelope() throws {
        let page = Page(items: [1, 2, 3], totalCount: 30, page: 2, size: 3)
        let mapped = page.map(String.init)
        XCTAssertEqual(mapped.items, ["1", "2", "3"])
        XCTAssertEqual(mapped.totalCount, 30)
        XCTAssertEqual(mapped.page, 2)
        XCTAssertEqual(mapped.size, 3)
    }

    func testPageAsyncMap() async throws {
        let page = Page(items: [1, 2], totalCount: 2, page: 1, size: 20)
        let mapped = await page.asyncMap { $0 * 10 }
        XCTAssertEqual(mapped.items, [10, 20])
        XCTAssertEqual(mapped.totalCount, 2)
    }

    func testPageEmpty() {
        let empty = Page<Int>.empty()
        XCTAssertTrue(empty.items.isEmpty)
        XCTAssertEqual(empty.totalCount, 0)
        XCTAssertEqual(empty.size, 20)
    }

    func testPageCodableWhenItemIsCodable() throws {
        let page = Page(items: ["a", "b"], totalCount: 2, page: 1, size: 20)
        let data = try JSONEncoder().encode(page)
        let decoded = try JSONDecoder().decode(Page<String>.self, from: data)
        XCTAssertEqual(decoded, page)
    }
}

final class UnitOfWorkTests: XCTestCase {

    func testNoopUnitOfWorkExecutesAndReturns() async throws {
        let result = try await NoopUnitOfWork().perform { 7 }
        XCTAssertEqual(result, 7)
    }

    func testNoopUnitOfWorkPropagatesErrors() async {
        do {
            _ = try await NoopUnitOfWork().perform { () -> Int in
                throw DomainError.conflict(message: "boom")
            }
            XCTFail("expected throw")
        } catch let error as DomainError {
            XCTAssertEqual(error, .conflict(message: "boom"))
        } catch {
            XCTFail("unexpected error type")
        }
    }
}

final class PrincipalTests: XCTestCase {

    func testIsAdmin() {
        XCTAssertTrue(Principal(userID: UUID(), roles: ["admin", "user"]).isAdmin)
        XCTAssertFalse(Principal(userID: UUID(), roles: ["user"]).isAdmin)
    }
}
