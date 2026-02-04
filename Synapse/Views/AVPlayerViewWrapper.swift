import SwiftUI
import AVKit
import AppKit

/// Wrapper pour AVPlayerView compatible macOS
@available(macOS 14.0, *)
struct AVPlayerViewWrapper: NSViewRepresentable {
    let player: AVPlayer?
    
    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.player = player
        playerView.controlsStyle = .none
        playerView.showsFullScreenToggleButton = false
        return playerView
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}
