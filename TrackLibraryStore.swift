import AVFoundation
import Foundation
import SwiftUI

struct TrackImportFailure: Identifiable {
    let id = UUID()
    let fileName: String
    let message: String
}

struct TrackImportReport {
    let tracks: [Track]
    let failures: [TrackImportFailure]
}

final class TrackLibraryStore {
    private static let supportedAudioExtensions: Set<String> = [
        "aac", "aif", "aiff", "caf", "m4a", "mp3", "wav"
    ]

    private let directoryURL: URL
    private let fileManager: FileManager
    private let isPlayableAudio: (URL) -> Bool
    private let cardColors: [Color] = [.purple, .indigo, .pink, .cyan, .orange, .mint]

    init(
        directoryURL: URL,
        fileManager: FileManager = .default,
        isPlayableAudio: ((URL) -> Bool)? = nil
    ) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
        self.isPlayableAudio = isPlayableAudio ?? { url in
            guard let player = try? AVAudioPlayer(contentsOf: url) else { return false }
            return player.duration > 0
        }
    }

    func restoreTracks() -> [Track] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return files
            .filter { url in
                guard Self.supportedAudioExtensions.contains(url.pathExtension.lowercased()),
                      let isRegularFile = try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                      isRegularFile == true,
                      isPlayableAudio(url) else {
                    return false
                }
                return true
            }
            .sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }
            .map(makeTrack(from:))
    }

    func importTracks(from sourceURLs: [URL]) -> TrackImportReport {
        guard !sourceURLs.isEmpty else {
            return TrackImportReport(tracks: [], failures: [])
        }

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            let failures = sourceURLs.map {
                TrackImportFailure(
                    fileName: $0.lastPathComponent,
                    message: "Не вдалося створити папку медіатеки. Перевірте вільне місце на пристрої."
                )
            }
            return TrackImportReport(tracks: [], failures: failures)
        }

        var importedTracks: [Track] = []
        var failures: [TrackImportFailure] = []

        for sourceURL in sourceURLs {
            let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            guard Self.supportedAudioExtensions.contains(sourceURL.pathExtension.lowercased()) else {
                failures.append(TrackImportFailure(
                    fileName: sourceURL.lastPathComponent,
                    message: "Цей формат не підтримується. Оберіть MP3, M4A, WAV, AIFF, AAC або CAF."
                ))
                continue
            }

            guard fileManager.isReadableFile(atPath: sourceURL.path) else {
                failures.append(TrackImportFailure(
                    fileName: sourceURL.lastPathComponent,
                    message: "Немає доступу до файлу. Спробуйте вибрати його ще раз у «Файлах»."
                ))
                continue
            }

            let destinationURL = uniqueDestinationURL(for: sourceURL)

            do {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)

                guard isPlayableAudio(destinationURL) else {
                    try? fileManager.removeItem(at: destinationURL)
                    failures.append(TrackImportFailure(
                        fileName: sourceURL.lastPathComponent,
                        message: "Файл пошкоджений або не містить аудіо."
                    ))
                    continue
                }

                importedTracks.append(makeTrack(from: destinationURL))
            } catch {
                try? fileManager.removeItem(at: destinationURL)
                failures.append(TrackImportFailure(
                    fileName: sourceURL.lastPathComponent,
                    message: "Не вдалося скопіювати файл у медіатеку. Перевірте вільне місце на пристрої."
                ))
            }
        }

        return TrackImportReport(tracks: importedTracks, failures: failures)
    }

    private func uniqueDestinationURL(for sourceURL: URL) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let fileExtension = sourceURL.pathExtension
        var candidate = directoryURL.appendingPathComponent(sourceURL.lastPathComponent)
        var suffix = 2

        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directoryURL.appendingPathComponent("\(baseName)-\(suffix).\(fileExtension)")
            suffix += 1
        }

        return candidate
    }

    private func makeTrack(from url: URL) -> Track {
        let rawName = url.deletingPathExtension().lastPathComponent
        let parts = rawName.components(separatedBy: " - ")
        let artist = parts.count > 1 ? parts[0] : "Невідомий виконавець"
        let title = parts.count > 1 ? parts.dropFirst().joined(separator: " - ") : rawName

        return Track(
            title: title,
            artist: artist,
            url: url,
            accentColor: cardColors.randomElement() ?? .purple
        )
    }
}
