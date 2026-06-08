import SwiftUI
import AVKit

struct VideoPlayerViewWrapper: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {}
}

class VideoDisplayLink {
    private var timer: Timer?

    init(callback: @escaping () -> Void) {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            callback()
        }
        timer?.tolerance = 0.01
    }

    func invalidate() {
        timer?.invalidate()
        timer = nil
    }
}
