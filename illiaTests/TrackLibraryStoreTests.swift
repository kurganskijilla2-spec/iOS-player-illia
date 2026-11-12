import XCTest
@testable import illia

final class TrackLibraryStoreTests: XCTestCase {
    private var temporaryRoot: URL!

    override func setUpWithError() throws {
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrackLibraryStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryRoot {
            try FileManager.default.removeItem(at: temporaryRoot)
        }
    }

    func testRestoreReturnsSupportedFilesInFilenameOrderAndSkipsMissingOrUnsupportedFiles() throws {
        let libraryURL = temporaryRoot.appendingPathComponent("Library", isDirectory: true)
        try FileManager.default.createDirectory(at: libraryURL, withIntermediateDirectories: true)
        try Data("zeta".utf8).write(to: libraryURL.appendingPathComponent("zeta.WAV"))
        try Data("alpha".utf8).write(to: libraryURL.appendingPathComponent("Alpha.mp3"))
        try Data("notes".utf8).write(to: libraryURL.appendingPathComponent("notes.txt"))
        try FileManager.default.createSymbolicLink(
            at: libraryURL.appendingPathComponent("missing.mp3"),
            withDestinationURL: temporaryRoot.appendingPathComponent("not-created.mp3")
        )

        let store = TrackLibraryStore(
            directoryURL: libraryURL,
            fileManager: .default,
            isPlayableAudio: { _ in true }
        )

        let tracks = store.restoreTracks()

        XCTAssertEqual(tracks.map { $0.url.lastPathComponent }, ["Alpha.mp3", "zeta.WAV"])
    }

    func testImportPreservesFilesWithDuplicateBasenames() throws {
        let firstDirectory = temporaryRoot.appendingPathComponent("first", isDirectory: true)
        let secondDirectory = temporaryRoot.appendingPathComponent("second", isDirectory: true)
        try FileManager.default.createDirectory(at: firstDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondDirectory, withIntermediateDirectories: true)

        let firstSource = firstDirectory.appendingPathComponent("Artist - Song.mp3")
        let secondSource = secondDirectory.appendingPathComponent("Artist - Song.mp3")
        try Data("first audio".utf8).write(to: firstSource)
        try Data("second audio".utf8).write(to: secondSource)

        let store = TrackLibraryStore(
            directoryURL: temporaryRoot.appendingPathComponent("Library", isDirectory: true),
            fileManager: .default,
            isPlayableAudio: { _ in true }
        )

        let report = store.importTracks(from: [firstSource, secondSource])

        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertEqual(report.tracks.count, 2)
        XCTAssertEqual(Set(report.tracks.map { $0.url.lastPathComponent }).count, 2)
        let importedContents = try report.tracks.map { try String(contentsOf: $0.url, encoding: .utf8) }
        XCTAssertEqual(Set(importedContents), Set(["first audio", "second audio"]))
    }

    func testImportReportsUndecodableAudioAndRemovesPartialCopy() throws {
        let source = temporaryRoot.appendingPathComponent("broken.mp3")
        try Data("this is not an audio file".utf8).write(to: source)
        let libraryURL = temporaryRoot.appendingPathComponent("Library", isDirectory: true)
        let store = TrackLibraryStore(directoryURL: libraryURL)

        let report = store.importTracks(from: [source])

        XCTAssertTrue(report.tracks.isEmpty)
        XCTAssertEqual(report.failures.count, 1)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: libraryURL.path), [])
    }

    func testImportReportsDestinationDirectoryFailureWithoutAddingTracks() throws {
        let source = temporaryRoot.appendingPathComponent("song.mp3")
        try Data("source audio".utf8).write(to: source)
        let blockedLibraryURL = temporaryRoot.appendingPathComponent("not-a-directory")
        try Data("block".utf8).write(to: blockedLibraryURL)
        let store = TrackLibraryStore(
            directoryURL: blockedLibraryURL,
            isPlayableAudio: { _ in true }
        )

        let report = store.importTracks(from: [source])

        XCTAssertTrue(report.tracks.isEmpty)
        XCTAssertEqual(report.failures.count, 1)
        XCTAssertEqual(try String(contentsOf: blockedLibraryURL, encoding: .utf8), "block")
    }
}
