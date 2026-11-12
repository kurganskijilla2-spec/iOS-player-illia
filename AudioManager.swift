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

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    private let cardColors: [Color] = [
        .purple, .indigo, .pink, .cyan, .orange, .mint
    ]

    override init() {
        super.init()
        setupAudioSession()
        setupRemoteTransportControls()
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
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }

            // Копіюємо файл у локальну папку додатка, щоб доступ не зник після перезапуску
            let fileManager = FileManager.default
            guard let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { continue }
            let destinationURL = docsDir.appendingPathComponent(url.lastPathComponent)

            do {
                if !fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.copyItem(at: url, to: destinationURL)
                }

                let rawName = destinationURL.deletingPathExtension().lastPathComponent
                let parts = rawName.components(separatedBy: " - ")
                let artist = parts.count > 1 ? parts[0] : "Невідомий виконавець"
                let title = parts.count > 1 ? parts[1] : rawName
                let randomColor = cardColors.randomElement() ?? .purple

                let newTrack = Track(title: title, artist: artist, url: destinationURL, accentColor: randomColor)
                if !tracks.contains(where: { $0.url == destinationURL }) {
                    tracks.append(newTrack)
                }
            } catch {
                print("Помилка копіювання файлу: \(error.localizedDescription)")
            }
        }

        if currentTrack == nil, let first = tracks.first {
            loadTrack(first, autoPlay: false)
        }
    }

    func loadTrack(_ track: Track, autoPlay: Bool = true) {
        stopTimer()
        currentTrack = track

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: track.url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
            currentTime = 0
            updateNowPlayingInfo()

            if autoPlay {
                play()
            } else {
                isPlaying = false
            }
        } catch {
            print("Не вдалося відкрити трек: \(error.localizedDescription)")
        }
    }

    func togglePlayPause() {
        guard currentTrack != nil else { return }
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        audioPlayer?.play()
        isPlaying = true
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
        audioPlayer?.currentTime = time
        currentTime = time
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
        guard let track = currentTrack else { return }
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
