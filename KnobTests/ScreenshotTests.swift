import XCTest
import PreviewScreenshots

final class ScreenshotTests: XCTestCase {
    @MainActor
    func testSaveAllPreviews() throws {
        let count = try PreviewScreenshots.saveAllPreviews()
        XCTAssertGreaterThan(count, 0, "Expected screenshots saved")
    }
}
