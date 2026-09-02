//
//  SpeechPlayer.swift
//  kupifa
//
//  Grok TTS の音声チャンクを順に再生する。
//

import AVFoundation
import Combine
import Foundation

@MainActor
final class SpeechPlayer: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var hasAudio = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    private var queue: [Data] = []
    private var index = 0
    private var player: AVAudioPlayer?
    private var tickTask: Task<Void, Never>?
    private var loadedDurations: [TimeInterval] = []

    func reset() {
        stopTimer()
        player?.stop()
        player = nil
        queue = []
        loadedDurations = []
        index = 0
        isPlaying = false
        hasAudio = false
        currentTime = 0
        duration = 0
    }

    func enqueue(_ data: Data) throws {
        guard !data.isEmpty else { return }
        queue.append(data)
        if let probe = try? AVAudioPlayer(data: data) {
            loadedDurations.append(probe.duration)
            duration = loadedDurations.reduce(0, +)
        }
        hasAudio = true
        if player == nil, isPlaying {
            playCurrent()
        }
    }

    func play() {
        guard hasAudio else { return }
        if let player, !player.isPlaying, index < queue.count {
            player.play()
            isPlaying = true
            startTimer()
            return
        }
        if player == nil {
            isPlaying = true
            playCurrent()
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func toggle() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        index = 0
        isPlaying = false
        currentTime = 0
        stopTimer()
    }

    private func playCurrent() {
        guard index < queue.count else {
            isPlaying = false
            stopTimer()
            return
        }
        do {
            let audio = try AVAudioPlayer(data: queue[index])
            audio.delegate = self
            audio.prepareToPlay()
            player = audio
            audio.play()
            isPlaying = true
            startTimer()
        } catch {
            isPlaying = false
        }
    }

    private func startTimer() {
        stopTimer()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.isPlaying else { break }
                self.refreshTime()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func stopTimer() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func refreshTime() {
        let finished = loadedDurations.prefix(index).reduce(0, +)
        currentTime = finished + (player?.currentTime ?? 0)
        duration = loadedDurations.reduce(0, +)
    }
}

extension SpeechPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.index += 1
            if self.index < self.queue.count {
                self.playCurrent()
            } else {
                self.isPlaying = false
                self.player = nil
                self.stopTimer()
                self.currentTime = self.duration
            }
        }
    }
}
