import SwiftUI
import AVKit

struct VideoScrubber: View {
    @ObservedObject var project: DemoProject
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(hex: "404040"))
                        .frame(height: 3)

                    ForEach(project.interactions) { interaction in
                        Circle()
                            .fill(Color(hex: "0A84FF"))
                            .frame(width: 6, height: 6)
                            .offset(x: xOffset(for: interaction.timestamp, in: geometry.size.width) - 3)
                    }

                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(hex: "0A84FF"))
                        .frame(width: xOffset(for: project.currentTime, in: geometry.size.width), height: 3)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 11, height: 11)
                        .offset(x: xOffset(for: project.currentTime, in: geometry.size.width) - 5.5)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDragging = true
                                    let progress = max(0, min(1, value.location.x / geometry.size.width))
                                    let newTime = CMTime(seconds: progress * project.videoDuration.seconds, preferredTimescale: 600)
                                    project.currentTime = newTime
                                }
                                .onEnded { _ in
                                    isDragging = false
                                }
                        )
                }
            }
            .frame(height: 11)

            HStack {
                Text(timeString(from: project.currentTime))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "888888"))

                Spacer()

                Text(timeString(from: project.videoDuration))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "888888"))
            }
        }
    }

    private func xOffset(for time: CMTime, in width: CGFloat) -> CGFloat {
        guard project.videoDuration.seconds > 0 else { return 0 }
        return CGFloat(time.seconds / project.videoDuration.seconds) * width
    }

    private func timeString(from time: CMTime) -> String {
        let seconds = time.seconds
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct InteractionControls: View {
    @ObservedObject var project: DemoProject
    let interaction: InteractionPoint

    var body: some View {
        HStack(spacing: 16) {
            Text("Point \(index)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "F0F0F0"))

            Text(timeString(from: interaction.timestamp))
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "0A84FF"))

            Divider()
                .frame(height: 20)
                .background(Color(hex: "404040"))

            HStack(spacing: 8) {
                Text("Zoom")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "888888"))

                Slider(
                    value: Binding(
                        get: { interaction.zoomLevel },
                        set: { project.updateInteraction(id: interaction.id, zoomLevel: $0) }
                    ),
                    in: 1.0...3.0  // 100% to 300%
                )
                .frame(width: 120)

                Text("\(Int(interaction.zoomLevel * 100))%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "F0F0F0"))
                    .frame(width: 40, alignment: .trailing)
            }

            Divider()
                .frame(height: 20)
                .background(Color(hex: "404040"))

            HStack(spacing: 8) {
                Text("Frame")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "888888"))

                HStack(spacing: 4) {
                    TextField("W", value: Binding(
                        get: { Int(interaction.frameSize.width) },
                        set: { project.updateInteraction(id: interaction.id, frameSize: CGSize(width: CGFloat($0), height: interaction.frameSize.height)) }
                    ), formatter: NumberFormatter())
                    .textFieldStyle(.plain)
                    .frame(width: 52)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color(hex: "2C2C2C"))
                    .cornerRadius(4)
                    .foregroundColor(Color(hex: "F0F0F0"))
                    .font(.system(size: 12, design: .monospaced))

                    Text("×")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "555555"))

                    TextField("H", value: Binding(
                        get: { Int(interaction.frameSize.height) },
                        set: { project.updateInteraction(id: interaction.id, frameSize: CGSize(width: interaction.frameSize.width, height: CGFloat($0))) }
                    ), formatter: NumberFormatter())
                    .textFieldStyle(.plain)
                    .frame(width: 52)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color(hex: "2C2C2C"))
                    .cornerRadius(4)
                    .foregroundColor(Color(hex: "F0F0F0"))
                    .font(.system(size: 12, design: .monospaced))
                }
            }

            Divider()
                .frame(height: 20)
                .background(Color(hex: "404040"))

            HStack(spacing: 8) {
                Text("Transition")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "888888"))

                Slider(
                    value: Binding(
                        get: { interaction.transitionDuration },
                        set: { project.updateInteraction(id: interaction.id, transitionDuration: $0) }
                    ),
                    in: 0.4...1.5
                )
                .frame(width: 80)

                Text(String(format: "%.1fs", interaction.transitionDuration))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "F0F0F0"))
                    .frame(width: 35, alignment: .trailing)
            }

            Spacer()
        }
    }

    private var index: Int {
        (project.interactions.firstIndex { $0.id == interaction.id } ?? 0) + 1
    }

    private func timeString(from time: CMTime) -> String {
        let seconds = time.seconds
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let tenths = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", mins, secs, tenths)
    }
}
