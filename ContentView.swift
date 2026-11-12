import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var showFileImporter = false
    @State private var isDraggingSlider = false
    @State private var sliderValue: TimeInterval = 0

    var body: some View {
        ZStack {
            // Адаптивний темний фон iOS із підсвіткою від активного треку
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    (audioManager.currentTrack?.accentColor ?? .purple).opacity(0.45),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.6), value: audioManager.currentTrack)

            VStack(spacing: 20) {
                // Верхня панель із логотипом illia та кнопкою додавання музики
                HStack {
                    Text("illia")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { showFileImporter = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Додати")
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Картка поточного треку (Now Playing)
                VStack(spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        audioManager.currentTrack?.accentColor ?? .purple,
                                        (audioManager.currentTrack?.accentColor ?? .indigo).opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 230, height: 230)
                            .shadow(color: (audioManager.currentTrack?.accentColor ?? .purple).opacity(0.5), radius: 25, x: 0, y: 12)
                            .scaleEffect(audioManager.isPlaying ? 1.0 : 0.92)
                            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: audioManager.isPlaying)

                        Image(systemName: "music.note")
                            .font(.system(size: 76, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }

                    // Назва та виконавець
                    VStack(spacing: 4) {
                        Text(audioManager.currentTrack?.title ?? "Оберіть трек")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(audioManager.currentTrack?.artist ?? "Натисніть «Додати» зверху")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    .padding(.horizontal)

                    // Шкала прогресу
                    VStack(spacing: 4) {
                        Slider(
                            value: Binding(
                                get: { isDraggingSlider ? sliderValue : audioManager.currentTime },
                                set: { newValue in
                                    sliderValue = newValue
                                    isDraggingSlider = true
                                }
                            ),
                            in: 0...max(audioManager.duration, 1),
                            onEditingChanged: { editing in
                                if !editing {
                                    audioManager.seek(to: sliderValue)
                                    isDraggingSlider = false
                                }
                            }
                        )
                        .tint(.white)

                        HStack {
                            Text(formatTime(isDraggingSlider ? sliderValue : audioManager.currentTime))
                            Spacer()
                            Text(formatTime(audioManager.duration))
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 24)

                    // Кнопки керування відтворенням
                    HStack(spacing: 32) {
                        Button(action: { audioManager.isShuffle.toggle() }) {
                            Image(systemName: "shuffle")
                                .font(.title3)
                                .foregroundColor(audioManager.isShuffle ? .pink : .white.opacity(0.6))
                        }

                        Button(action: { audioManager.previousTrack() }) {
                            Image(systemName: "backward.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }

                        Button(action: { audioManager.togglePlayPause() }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 68, height: 68)

                                Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title)
                                    .foregroundColor(.black)
                                    .offset(x: audioManager.isPlaying ? 0 : 2)
                            }
                        }

                        Button(action: { audioManager.nextTrack() }) {
                            Image(systemName: "forward.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }

                        Button(action: { audioManager.isRepeat.toggle() }) {
                            Image(systemName: "repeat")
                                .font(.title3)
                                .foregroundColor(audioManager.isRepeat ? .pink : .white.opacity(0.6))
                        }
                    }
                }

                // Список завантажених треків
                VStack(alignment: .leading, spacing: 10) {
                    Text("Медіатека (\(audioManager.tracks.count))")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal)

                    if audioManager.tracks.isEmpty {
                        VStack(spacing: 8) {
                            Spacer()
                            Text("Тут поки порожньо")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white.opacity(0.6))
                            Text("Завантажте MP3, M4A або WAV із додатка «Файли»")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(audioManager.tracks) { track in
                                    TrackRowView(
                                        track: track,
                                        isCurrent: audioManager.currentTrack == track,
                                        isPlaying: audioManager.isPlaying && audioManager.currentTrack == track
                                    )
                                    .onTapGesture {
                                        audioManager.loadTrack(track, autoPlay: true)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.top, 6)
            }
        }
        .preferredColorScheme(.dark)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                audioManager.importTracks(from: urls)
            case .failure(let error):
                audioManager.errorMessage = error.localizedDescription
            }
        }
        .alert(
            "Помилка",
            isPresented: Binding(
                get: { audioManager.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        audioManager.errorMessage = nil
                    }
                }
            )
        ) {
            Button("Гаразд", role: .cancel) {
                audioManager.errorMessage = nil
            }
        } message: {
            Text(audioManager.errorMessage ?? "Сталася невідома помилка.")
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN && !time.isInfinite else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct TrackRowView: View {
    let track: Track
    let isCurrent: Bool
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(track.accentColor.opacity(0.35))
                    .frame(width: 48, height: 48)

                Image(systemName: isPlaying ? "waveform" : "music.note")
                    .foregroundColor(isCurrent ? track.accentColor : .white)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.body.weight(.semibold))
                    .foregroundColor(isCurrent ? track.accentColor : .white)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(10)
        .background(.ultraThinMaterial.opacity(isCurrent ? 0.9 : 0.45))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
