import SwiftUI
import AVKit

struct SourceVideoView: View {
    @ObservedObject var project: DemoProject
    @State private var player: AVPlayer?
    @State private var displayLink: VideoDisplayLink?
    @State private var draggingMarkerID: UUID?
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                gridBackground

                if let player = player {
                    let videoFrame = calculateVideoFrame(in: geometry.size)

                    ZStack {
                        // Raw video player (no zoom effects)
                        VideoPlayerViewWrapper(player: player)
                            .frame(width: videoFrame.width, height: videoFrame.height)

                        // Keyframe markers overlay
                        ForEach(Array(project.interactions.enumerated()), id: \.element.id) { index, interaction in
                            let isDragging = draggingMarkerID == interaction.id
                            let basePosition = CGPoint(
                                x: interaction.position.x * videoFrame.width,
                                y: interaction.position.y * videoFrame.height
                            )
                            let displayPosition = isDragging
                                ? CGPoint(x: basePosition.x + dragOffset.width, y: basePosition.y + dragOffset.height)
                                : basePosition

                            KeyframeMarkerView(
                                number: index + 1,
                                isSelected: interaction.id == project.selectedInteractionID,
                                isDragging: isDragging
                            )
                            .position(displayPosition)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if draggingMarkerID == nil {
                                            draggingMarkerID = interaction.id
                                            project.selectedInteractionID = interaction.id
                                        }
                                        dragOffset = value.translation
                                    }
                                    .onEnded { value in
                                        let newX = (basePosition.x + value.translation.width) / videoFrame.width
                                        let newY = (basePosition.y + value.translation.height) / videoFrame.height

                                        // Clamp to 0-1 range
                                        let clampedPosition = CGPoint(
                                            x: max(0, min(1, newX)),
                                            y: max(0, min(1, newY))
                                        )

                                        if let idx = project.interactions.firstIndex(where: { $0.id == interaction.id }) {
                                            project.interactions[idx].position = clampedPosition
                                        }

                                        draggingMarkerID = nil
                                        dragOffset = .zero
                                    }
                            )
                            .onTapGesture {
                                project.selectedInteractionID = interaction.id
                                project.currentTime = interaction.timestamp
                            }
                        }
                    }
                    .position(x: videoFrame.midX, y: videoFrame.midY)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        // Add keyframe at click position
                        handleTap(at: location, in: videoFrame, containerSize: geometry.size)
                    }
                }
            }
        }
        .background(Color(hex: "111111"))
        .onAppear {
            setupPlayer()
            setupDisplayLink()
            setupNotifications()
        }
        .onDisappear {
            displayLink?.invalidate()
            NotificationCenter.default.removeObserver(self)
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
        displayLink = VideoDisplayLink { [weak player] in
            guard let player = player else { return }
            let playerTime = player.currentTime()

            if abs(playerTime.seconds - project.currentTime.seconds) > 0.1 {
                DispatchQueue.main.async {
                    project.currentTime = playerTime
                }
            }
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PlayVideo"),
            object: nil,
            queue: .main
        ) { [weak player] _ in
            player?.play()
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PauseVideo"),
            object: nil,
            queue: .main
        ) { [weak player] _ in
            player?.pause()
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SeekPlayer"),
            object: nil,
            queue: .main
        ) { [weak player] notification in
            if let time = notification.object as? CMTime {
                player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
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

    private func handleTap(at location: CGPoint, in videoFrame: CGRect, containerSize: CGSize) {
        guard project.canAddInteraction else { return }

        // Convert tap location to video frame coordinates
        let videoX = location.x - (containerSize.width - videoFrame.width) / 2
        let videoY = location.y - (containerSize.height - videoFrame.height) / 2

        // Check if tap is within video bounds
        guard videoX >= 0, videoX <= videoFrame.width,
              videoY >= 0, videoY <= videoFrame.height else {
            return
        }

        let relativeX = videoX / videoFrame.width
        let relativeY = videoY / videoFrame.height

        let normalizedPosition = CGPoint(
            x: max(0, min(1, relativeX)),
            y: max(0, min(1, relativeY))
        )

        project.addInteraction(at: project.currentTime, position: normalizedPosition)
    }
}

struct KeyframeMarkerView: View {
    let number: Int
    let isSelected: Bool
    let isDragging: Bool

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(Color(hex: "0A84FF").opacity(0.25))
                    .frame(width: 44, height: 44)
            }

            Circle()
                .fill(isSelected ? Color(hex: "0A84FF") : Color(hex: "444444"))
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.white : Color(hex: "666666"), lineWidth: 2)
                )

            Text("\(number)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
        }
        .scaleEffect(isDragging ? 1.2 : 1.0)
        .shadow(color: .black.opacity(isDragging ? 0.4 : 0.2), radius: isDragging ? 8 : 4)
        .animation(.spring(response: 0.3), value: isDragging)
    }
}
