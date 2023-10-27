import XCTest

func XCTAssertEqualAsync<T: Equatable>(
        _ expression1: @autoclosure () async throws -> T,
        _ expression2: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async rethrows {
        let e1 = try await expression1()
        let e2 = try await expression2()
        XCTAssertEqual(e1, e2, message(), file: file, line: line)
}
