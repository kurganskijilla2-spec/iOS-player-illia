import Foundation
import AVFoundation
import Combine
import SwiftUI
import MediaPlayer

class AudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var tracks: [Track] = []
    @Published var currentTrack: Track?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isShuffle: Bool = false
    @Published var isRepeat: Bool = false
    @Published var errorMessage: String?

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private let libraryStore: TrackLibraryStore

    init(libraryStore: TrackLibraryStore? = nil) {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.libraryStore = libraryStore ?? TrackLibraryStore(directoryURL: documentsDirectory)
        super.init()
        setupAudioSession()
        setupRemoteTransportControls()

        tracks = self.libraryStore.restoreTracks()
        if let firstTrack = tracks.first {
            loadTrack(firstTrack, autoPlay: false)
        }
    }

    // Налаштування аудіосесії для роботи у фоні
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Помилка налаштування AVAudioSession: \(error.localizedDescription)")
        }
    }

    // Імпорт аудіофайлів з пам'яті iPhone
    func importTracks(from urls: [URL]) {
        errorMessage = nil
        let report = libraryStore.importTracks(from: urls)
        let existingURLs = Set(tracks.map { $0.url.standardizedFileURL })
        tracks.append(contentsOf: report.tracks.filter {
            !existingURLs.contains($0.url.standardizedFileURL)
        })

        if currentTrack == nil, let first = tracks.first {
            loadTrack(first, autoPlay: false)
        }

        if !report.failures.isEmpty {
            let fileNames = report.failures.map(\.fileName).joined(separator: ", ")
            let firstMessage = report.failures[0].message
            errorMessage = "Не вдалося додати \(report.failures.count) файлів (\(fileNames)). \(firstMessage)"
        }
    }

    func loadTrack(_ track: Track, autoPlay: Bool = true) {
        stopTimer()
        audioPlayer = nil
        currentTrack = track
        isPlaying = false
        duration = 0
        currentTime = 0

        do {
            let player = try AVAudioPlayer(contentsOf: track.url)
            player.delegate = self
            player.prepareToPlay()
            audioPlayer = player
            duration = player.duration
            errorMessage = nil
            updateNowPlayingInfo()

            if autoPlay {
                play()
            }
        } catch {
            errorMessage = "Не вдалося відкрити «\(track.title)». Перевірте, чи файл не пошкоджено."
            updateNowPlayingInfo()
        }
    }

    func togglePlayPause() {
        guard currentTrack != nil else {
            errorMessage = "Спочатку оберіть або додайте аудіотрек."
            return
        }

        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        guard let player = audioPlayer else {
            isPlaying = false
            stopTimer()
            errorMessage = currentTrack == nil
                ? "Спочатку оберіть або додайте аудіотрек."
                : "Не вдалося відкрити аудіотрек для відтворення."
            updateNowPlayingInfo()
            return
        }

        guard player.play() else {
            isPlaying = false
            stopTimer()
            errorMessage = "Не вдалося запустити відтворення цього аудіотреку."
            updateNowPlayingInfo()
            return
        }

        isPlaying = true
        errorMessage = nil
        startTimer()
        updateNowPlayingInfo()
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
        updateNowPlayingInfo()
    }

    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        let boundedTime = min(max(time, 0), duration)
        player.currentTime = boundedTime
        currentTime = boundedTime
        updateNowPlayingInfo()
    }

    func nextTrack() {
        guard !tracks.isEmpty else { return }
        if isShuffle {
            if let randomTrack = tracks.randomElement() {
                loadTrack(randomTrack, autoPlay: true)
            }
            return
        }

        if let current = currentTrack, let index = tracks.firstIndex(of: current) {
            let nextIndex = (index + 1) % tracks.count
            loadTrack(tracks[nextIndex], autoPlay: true)
        } else if let first = tracks.first {
            loadTrack(first, autoPlay: true)
        }
    }

    func previousTrack() {
        guard !tracks.isEmpty else { return }
        if currentTime > 3.0 {
            seek(to: 0)
            return
        }

        if let current = currentTrack, let index = tracks.firstIndex(of: current) {
            let prevIndex = (index - 1 + tracks.count) % tracks.count
            loadTrack(tracks[prevIndex], autoPlay: true)
        }
    }

    // Автоматичний перехід до наступного треку після завершення
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard flag else {
            isPlaying = false
            stopTimer()
            errorMessage = "Відтворення аудіотреку завершилося з помилкою."
            updateNowPlayingInfo()
            return
        }

        if isRepeat {
            seek(to: 0)
            play()
        } else {
            nextTrack()
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
            self.updateNowPlayingInfo()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // Відображення плеєра на екрані блокування iPhone
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextTrack()
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousTrack()
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
