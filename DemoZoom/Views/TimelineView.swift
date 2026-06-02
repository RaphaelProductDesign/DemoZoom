import SwiftUI
import AVFoundation

struct TimelineView: View {
    @ObservedObject var project: DemoProject
    @State private var isDraggingPlayhead = false
    @State private var draggingKeyframeID: UUID?
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 12) {
            // Timeline track
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "404040"))
                        .frame(height: 4)

                    // Progress fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "0A84FF"))
                        .frame(width: xOffset(for: project.currentTime, in: geometry.size.width), height: 4)

                    // Keyframe markers
                    ForEach(Array(project.interactions.enumerated()), id: \.element.id) { index, interaction in
                        let isDragging = draggingKeyframeID == interaction.id
                        let baseOffset = xOffset(for: interaction.timestamp, in: geometry.size.width)
                        let displayOffset = isDragging ? baseOffset + dragOffset : baseOffset

                        KeyframeMarker(
                            number: index + 1,
                            isSelected: interaction.id == project.selectedInteractionID,
                            isDragging: isDragging
                        )
                        .offset(x: displayOffset - 10)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if draggingKeyframeID == nil {
                                        draggingKeyframeID = interaction.id
                                    }
                                    dragOffset = value.translation.width
                                }
                                .onEnded { value in
                                    let newOffset = baseOffset + value.translation.width
                                    let progress = max(0, min(1, newOffset / geometry.size.width))
                                    let newTime = CMTime(
                                        seconds: progress * project.videoDuration.seconds,
                                        preferredTimescale: 600
                                    )

                                    // Update timestamp
                                    if let idx = project.interactions.firstIndex(where: { $0.id == interaction.id }) {
                                        project.interactions[idx].timestamp = newTime
                                        project.interactions.sort { $0.timestamp.seconds < $1.timestamp.seconds }
                                    }

                                    draggingKeyframeID = nil
                                    dragOffset = 0
                                }
                        )
                        .onTapGesture {
                            project.selectedInteractionID = interaction.id
                            project.currentTime = interaction.timestamp
                        }
                    }

                    // Playhead
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .offset(x: xOffset(for: project.currentTime, in: geometry.size.width) - 7)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDraggingPlayhead = true
                                    let progress = max(0, min(1, value.location.x / geometry.size.width))
                                    let newTime = CMTime(
                                        seconds: progress * project.videoDuration.seconds,
                                        preferredTimescale: 600
                                    )
                                    project.currentTime = newTime
                                }
                                .onEnded { _ in
                                    isDraggingPlayhead = false
                                }
                        )
                }
                .frame(height: 40)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    // Add new keyframe at clicked position
                    guard project.canAddInteraction else { return }
                    let progress = location.x / geometry.size.width
                    let newTime = CMTime(
                        seconds: progress * project.videoDuration.seconds,
                        preferredTimescale: 600
                    )
                    project.currentTime = newTime
                    // User needs to click on video to add keyframe
                }
            }
            .frame(height: 40)
            .padding(.horizontal, 16)

            // Time labels
            HStack {
                Text(timeString(from: project.currentTime))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "F0F0F0"))

                Spacer()

                Text(timeString(from: project.videoDuration))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "888888"))
            }
            .padding(.horizontal, 16)

            // Keyframe controls (if selected)
            if let selected = project.selectedInteraction {
                Divider()
                    .background(Color(hex: "333333"))

                InteractionControls(project: project, interaction: selected)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .padding(.vertical, 12)
        .background(Color(hex: "242424"))
    }

    private func xOffset(for time: CMTime, in width: CGFloat) -> CGFloat {
        guard project.videoDuration.seconds > 0 else { return 0 }
        return CGFloat(time.seconds / project.videoDuration.seconds) * width
    }

    private func timeString(from time: CMTime) -> String {
        let seconds = time.seconds
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let frames = Int((seconds.truncatingRemainder(dividingBy: 1)) * 30)
        return String(format: "%d:%02d:%02d", mins, secs, frames)
    }
}

struct KeyframeMarker: View {
    let number: Int
    let isSelected: Bool
    let isDragging: Bool

    var body: some View {
        ZStack {
            // Diamond shape
            Diamond()
                .fill(isSelected ? Color(hex: "0A84FF") : Color(hex: "888888"))
                .frame(width: 20, height: 20)
                .shadow(color: .black.opacity(0.3), radius: isDragging ? 4 : 2)

            // Number
            Text("\(number)")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
        }
        .scaleEffect(isDragging ? 1.2 : 1.0)
        .animation(.spring(response: 0.3), value: isDragging)
    }
}

struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        path.move(to: CGPoint(x: center.x, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: center.y))
        path.addLine(to: CGPoint(x: center.x, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: center.y))
        path.closeSubpath()

        return path
    }
}
