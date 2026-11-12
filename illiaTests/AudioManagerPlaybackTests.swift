import XCTest
@testable import illia

final class AudioManagerPlaybackTests: XCTestCase {
    func testPlayControlWithoutLoadedAudioRemainsPausedAndPublishesAnError() {
        let libraryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioManagerPlaybackTests-\(UUID().uuidString)", isDirectory: true)
        let store = TrackLibraryStore(directoryURL: libraryURL)
        let manager = AudioManager(libraryStore: store)

        manager.togglePlayPause()

        XCTAssertFalse(manager.isPlaying)
        XCTAssertEqual(manager.errorMessage, "Спочатку оберіть або додайте аудіотрек.")
    }
}
