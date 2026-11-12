import XCTest
@testable import illia

final class IlliaSmokeTests: XCTestCase {
    func testTrackCanBeCreatedFromFileURL() {
        let track = Track(
            title: "Smoke test",
            artist: "illia",
            url: URL(fileURLWithPath: "/tmp/smoke-test.mp3"),
            accentColor: .purple
        )

        XCTAssertEqual(track.title, "Smoke test")
        XCTAssertEqual(track.artist, "illia")
    }
}
