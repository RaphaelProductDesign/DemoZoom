import SwiftUI
import AVKit

struct OutputPreviewView: View {
    @ObservedObject var project: DemoProject
    @State private var player: AVPlayer?
    @State private var displayLink: VideoDisplayLink?
    @State private var isDraggingEdge: ResizeEdge?
    @State private var dragStartSize: CGSize = .zero

    enum ResizeEdge {
        case right, bottom, corner
    }

    var body: some View {
        VStack(spacing: 0) {
            // Frame size controls
            HStack(spacing: 8) {
                Text("Output Frame")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "888888"))

                Spacer()

                TextField("Width", value: Binding(
                    get: { Int(project.defaultFrameSize.width) },
                    set: { project.defaultFrameSize.width = CGFloat($0) }
                ), formatter: NumberFormatter())
                .textFieldStyle(.plain)
                .frame(width: 55)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "2C2C2C"))
                .cornerRadius(4)
                .foregroundColor(Color(hex: "F0F0F0"))
                .font(.system(size: 12, design: .monospaced))

                Text("×")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "555555"))

                TextField("Height", value: Binding(
                    get: { Int(project.defaultFrameSize.height) },
                    set: { project.defaultFrameSize.height = CGFloat($0) }
                ), formatter: NumberFormatter())
                .textFieldStyle(.plain)
                .frame(width: 55)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "2C2C2C"))
                .cornerRadius(4)
                .foregroundColor(Color(hex: "F0F0F0"))
                .font(.system(size: 12, design: .monospaced))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: "1A1A1A"))

            // Live preview with zoom effects
            GeometryReader { geometry in
                ZStack {
                    Color(hex: "0D0D0D")

                    if let player = player {
                        let previewSize = calculatePreviewSize(in: geometry.size)

                        ZStack {
                            VideoPlayerViewWrapper(player: player)
                                .frame(width: previewSize.width, height: previewSize.height)
                                .overlay(
                                    centerCrosshair(for: previewSize)
                                )
                                .overlay(
                                    resizeHandles(for: previewSize)
                                )
                        }
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }

                    // Dimension overlay
                    if project.defaultFrameSize.width > 0 {
                        VStack {
                            Spacer()
                            Text("\(Int(project.defaultFrameSize.width)) × \(Int(project.defaultFrameSize.height))")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(Color(hex: "888888"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(hex: "1A1A1A").opacity(0.8))
                                .cornerRadius(6)
                                .padding(.bottom, 16)
                        }
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
        .onChange(of: project.interactions) { _ in
            updateComposition()
        }
        .onChange(of: project.defaultFrameSize) { _ in
            updateComposition()
        }
    }

    private func centerCrosshair(for frameSize: CGSize) -> some View {
        ZStack {
            // Horizontal line
            Rectangle()
                .fill(Color(hex: "0A84FF").opacity(0.5))
                .frame(width: 20, height: 1)
                .position(x: frameSize.width / 2, y: frameSize.height / 2)

            // Vertical line
            Rectangle()
                .fill(Color(hex: "0A84FF").opacity(0.5))
                .frame(width: 1, height: 20)
                .position(x: frameSize.width / 2, y: frameSize.height / 2)

            // Center dot
            Circle()
                .fill(Color(hex: "0A84FF"))
                .frame(width: 4, height: 4)
                .position(x: frameSize.width / 2, y: frameSize.height / 2)
        }
        .opacity(project.selectedInteractionID != nil ? 0.8 : 0.3)
    }

    private func resizeHandles(for frameSize: CGSize) -> some View {
        ZStack {
            // Right edge handle
            Rectangle()
                .fill(Color.white.opacity(isDraggingEdge == .right ? 0.3 : 0.0))
                .frame(width: 8, height: frameSize.height)
                .position(x: frameSize.width, y: frameSize.height / 2)
                .cursor(.resizeLeftRight)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if isDraggingEdge == nil {
                                isDraggingEdge = .right
                                dragStartSize = project.defaultFrameSize
                            }
                            let newWidth = dragStartSize.width + value.translation.width
                            project.defaultFrameSize.width = max(100, newWidth)
                        }
                        .onEnded { _ in
                            isDraggingEdge = nil
                        }
                )

            // Bottom edge handle
            Rectangle()
                .fill(Color.white.opacity(isDraggingEdge == .bottom ? 0.3 : 0.0))
                .frame(width: frameSize.width, height: 8)
                .position(x: frameSize.width / 2, y: frameSize.height)
                .cursor(.resizeUpDown)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if isDraggingEdge == nil {
                                isDraggingEdge = .bottom
                                dragStartSize = project.defaultFrameSize
                            }
                            let newHeight = dragStartSize.height + value.translation.height
                            project.defaultFrameSize.height = max(100, newHeight)
                        }
                        .onEnded { _ in
                            isDraggingEdge = nil
                        }
                )

            // Corner handle (visual indicator)
            Circle()
                .fill(Color(hex: "0A84FF"))
                .frame(width: 12, height: 12)
                .position(x: frameSize.width, y: frameSize.height)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if isDraggingEdge == nil {
                                isDraggingEdge = .corner
                                dragStartSize = project.defaultFrameSize
                            }
                            let newWidth = dragStartSize.width + value.translation.width
                            let newHeight = dragStartSize.height + value.translation.height
                            project.defaultFrameSize.width = max(100, newWidth)
                            project.defaultFrameSize.height = max(100, newHeight)
                        }
                        .onEnded { _ in
                            isDraggingEdge = nil
                        }
                )
        }
    }

    private func calculatePreviewSize(in containerSize: CGSize) -> CGSize {
        let frameAspectRatio = project.defaultFrameSize.width / project.defaultFrameSize.height
        let containerAspectRatio = containerSize.width / containerSize.height

        // Fit preview in container while maintaining output aspect ratio
        if frameAspectRatio > containerAspectRatio {
            let width = containerSize.width * 0.8
            let height = width / frameAspectRatio
            return CGSize(width: width, height: height)
        } else {
            let height = containerSize.height * 0.8
            let width = height * frameAspectRatio
            return CGSize(width: width, height: height)
        }
    }

    private func setupPlayer() {
        guard let url = project.videoURL else { return }

        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.volume = 0
        self.player = newPlayer

        updateComposition()
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

    private func updateComposition() {
        guard let url = project.videoURL,
              let playerItem = player?.currentItem,
              !project.interactions.isEmpty else {
            return
        }

        Task {
            let asset = AVAsset(url: url)
            let processor = VideoProcessor()

            do {
                let composition = try await processor.generateComposition(
                    for: asset,
                    interactions: project.interactions,
                    videoSize: project.videoSize
                )

                await MainActor.run {
                    playerItem.videoComposition = composition
                }
            } catch {
                print("Failed to generate composition: \(error)")
            }
        }
    }
}

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { hovering in
            if hovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
