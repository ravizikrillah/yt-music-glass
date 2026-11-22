import AppKit
import Foundation
import MediaPlayer

@MainActor
final class NowPlayingBridge {
    private var lastArtworkUrl: String? = nil
    private var cachedArtwork: MPMediaItemArtwork? = nil
    private var isConfigured = false

    func configure(
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onTogglePlay: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onPrev: @escaping () -> Void,
        onSeek: @escaping (Double) -> Void
    ) {
        guard !isConfigured else { return }
        isConfigured = true

        let cc = MPRemoteCommandCenter.shared()

        cc.playCommand.isEnabled = true
        cc.playCommand.addTarget { _ in
            Task { @MainActor in onPlay() }
            return .success
        }

        cc.pauseCommand.isEnabled = true
        cc.pauseCommand.addTarget { _ in
            Task { @MainActor in onPause() }
            return .success
        }

        cc.togglePlayPauseCommand.isEnabled = true
        cc.togglePlayPauseCommand.addTarget { _ in
            Task { @MainActor in onTogglePlay() }
            return .success
        }

        cc.nextTrackCommand.isEnabled = true
        cc.nextTrackCommand.addTarget { _ in
            Task { @MainActor in onNext() }
            return .success
        }

        cc.previousTrackCommand.isEnabled = true
        cc.previousTrackCommand.addTarget { _ in
            Task { @MainActor in onPrev() }
            return .success
        }

        cc.changePlaybackPositionCommand.isEnabled = true
        cc.changePlaybackPositionCommand.addTarget { event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let target = posEvent.positionTime
            Task { @MainActor in onSeek(target) }
            return .success
        }
    }

    func update(track: TrackInfo?, playback: PlaybackSnapshot, artwork: NSImage?) {
        let center = MPNowPlayingInfoCenter.default()

        guard let track, !track.title.isEmpty else {
            center.nowPlayingInfo = nil
            center.playbackState = .stopped
            lastArtworkUrl = nil
            cachedArtwork = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: max(0, playback.currentTime),
            MPNowPlayingInfoPropertyPlaybackRate: playback.paused ? 0.0 : max(0.25, playback.playbackRate),
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
        ]

        if let album = track.album, !album.isEmpty {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        if playback.duration.isFinite && playback.duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = playback.duration
        }

        if let artwork {
            let artKey = track.artworkUrl ?? "\(track.title)::\(track.artist)"
            if artKey != lastArtworkUrl || cachedArtwork == nil {
                lastArtworkUrl = artKey
                let size = artwork.size.width > 0 ? artwork.size : NSSize(width: 226, height: 226)
                cachedArtwork = MPMediaItemArtwork(boundsSize: size) { _ in artwork }
            }
            if let mpArt = cachedArtwork {
                info[MPMediaItemPropertyArtwork] = mpArt
            }
        }

        center.nowPlayingInfo = info
        center.playbackState = playback.paused ? .paused : .playing
    }
}
