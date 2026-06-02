import SwiftUI
import AVKit

struct PreviewView: View {
    @ObservedObject var project: DemoProject
    let videoURL: URL
    @Binding var isPresented: Bool

    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Preview")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "F0F0F0"))

                Spacer()

                Button("Close") {
                    isPresented = false
                }
                .buttonStyle(ToolbarButtonStyle())
            }
            .padding(16)
            .background(Color(hex: "242424"))

            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
                        .tint(Color(hex: "0A84FF"))
                } else if let error = error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "FF453A"))

                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "888888"))
                    }
                } else if let player = player {
                    VideoPlayerView(player: player)
                        .aspectRatio(project.videoSize, contentMode: .fit)
                        .background(Color.black)
                        .onAppear {
                            player.seek(to: .zero)
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "111111"))
        }
        .frame(width: 900, height: 700)
        .background(Color(hex: "1A1A1A"))
        .onAppear {
            Task {
                await generatePreview()
            }
        }
    }

    private func generatePreview() async {
        do {
            let asset = AVAsset(url: videoURL)
            let processor = VideoProcessor()

            let composition = try await processor.generateComposition(
                for: asset,
                interactions: project.interactions,
                videoSize: project.videoSize
            )

            let playerItem = AVPlayerItem(asset: asset)
            playerItem.videoComposition = composition

            let newPlayer = AVPlayer(playerItem: playerItem)

            await MainActor.run {
                self.player = newPlayer
                self.isLoading = false
                newPlayer.play()
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
