import SwiftUI
import AVKit

struct VideoEditorView: View {
    @ObservedObject var project: DemoProject
    @State private var player: AVPlayer?
    @State private var displayLink: DisplayLink?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                gridBackground

                if let player = player {
                    let videoFrame = calculateVideoFrame(in: geometry.size)

                    ZStack {
                        VideoPlayerView(player: player)
                            .frame(width: videoFrame.width, height: videoFrame.height)

                        InteractionOverlay(
                            project: project,
                            videoSize: project.videoSize,
                            containerSize: CGSize(width: videoFrame.width, height: videoFrame.height)
                        )
                        .frame(width: videoFrame.width, height: videoFrame.height)
                    }
                    .position(x: videoFrame.midX, y: videoFrame.midY)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        handleTap(at: location, in: videoFrame)
                    }
                }
            }
        }
        .background(Color(hex: "111111"))
        .onAppear {
            setupPlayer()
            setupDisplayLink()
        }
        .onDisappear {
            displayLink?.invalidate()
        }
    }

    private var gridBackground: some View {
        Canvas { context, size in
            let spacing: CGFloat = 20

            context.stroke(
                Path { path in
                    for x in stride(from: 0, to: size.width, by: spacing) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for y in stride(from: 0, to: size.height, by: spacing) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                },
                with: .color(.white.opacity(0.015)),
                lineWidth: 1
            )
        }
    }

    private func setupPlayer() {
        guard let url = project.videoURL else { return }

        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.volume = 0
        self.player = newPlayer
    }

    private func setupDisplayLink() {
        displayLink = DisplayLink { [weak player] in
            guard let player = player else { return }
            let currentTime = player.currentTime()
            if currentTime != project.currentTime {
                project.currentTime = currentTime
            }
        }
    }

    private func calculateVideoFrame(in containerSize: CGSize) -> CGRect {
        let aspectRatio = project.videoSize.width / project.videoSize.height
        let containerAspectRatio = containerSize.width / containerSize.height

        var videoFrame: CGRect

        if aspectRatio > containerAspectRatio {
            let height = containerSize.width / aspectRatio
            videoFrame = CGRect(
                x: 0,
                y: (containerSize.height - height) / 2,
                width: containerSize.width,
                height: height
            )
        } else {
            let width = containerSize.height * aspectRatio
            videoFrame = CGRect(
                x: (containerSize.width - width) / 2,
                y: 0,
                width: width,
                height: containerSize.height
            )
        }

        return videoFrame
    }

    private func handleTap(at location: CGPoint, in videoFrame: CGRect) {
        // Tap is already within video frame bounds due to contentShape
        let relativeX = location.x / videoFrame.width
        let relativeY = location.y / videoFrame.height

        // Clamp to 0-1 range
        let normalizedPosition = CGPoint(
            x: max(0, min(1, relativeX)),
            y: max(0, min(1, relativeY))
        )

        project.addInteraction(at: project.currentTime, position: normalizedPosition)
    }
}

struct VideoPlayerView: NSViewRepresentable {
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

struct InteractionOverlay: View {
    @ObservedObject var project: DemoProject
    let videoSize: CGSize
    let containerSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            ForEach(project.interactions) { interaction in
                let position = convertPosition(interaction.position, to: containerSize)

                ZStack {
                    if interaction.id == project.selectedInteractionID {
                        Circle()
                            .fill(Color(hex: "0A84FF").opacity(0.25))
                            .frame(width: 44, height: 44)
                    }

                    Circle()
                        .fill(interaction.id == project.selectedInteractionID ? Color(hex: "0A84FF") : Color(hex: "444444"))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle()
                                .stroke(interaction.id == project.selectedInteractionID ? Color.white : Color(hex: "666666"), lineWidth: 2)
                        )

                    Text("\(index(of: interaction) + 1)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                .position(position)
                .onTapGesture {
                    project.selectedInteractionID = interaction.id
                }
            }
        }
    }

    private func convertPosition(_ normalized: CGPoint, to size: CGSize) -> CGPoint {
        return CGPoint(
            x: normalized.x * size.width,
            y: normalized.y * size.height
        )
    }

    private func index(of interaction: InteractionPoint) -> Int {
        project.interactions.firstIndex { $0.id == interaction.id } ?? 0
    }
}

class DisplayLink {
    private var displayLink: CVDisplayLink?
    private var timer: Timer?

    init(callback: @escaping () -> Void) {
        // Use Timer instead of CVDisplayLink to avoid unsafe pointer issues
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            callback()
        }
        timer?.tolerance = 0.01
    }

    func invalidate() {
        timer?.invalidate()
        timer = nil

        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
    }
}
