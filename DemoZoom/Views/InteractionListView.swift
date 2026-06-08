import SwiftUI
import AVFoundation

struct InteractionListView: View {
    @ObservedObject var project: DemoProject

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("INTERACTIONS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "555555"))

                Spacer()

                Text("\(project.interactions.count) / 10")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "555555"))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(project.interactions.enumerated()), id: \.element.id) { index, interaction in
                        InteractionRowView(
                            project: project,
                            interaction: interaction,
                            index: index + 1
                        )
                    }
                }
                .padding(.horizontal, 8)
            }

            if project.canAddInteraction {
                Button(action: {}) {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 11))
                        Text("Tap video to add")
                            .font(.system(size: 12))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "2C2C2C"))
                    .foregroundColor(Color(hex: "888888"))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(hex: "404040"), lineWidth: 1)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
    }
}

struct InteractionRowView: View {
    @ObservedObject var project: DemoProject
    let interaction: InteractionPoint
    let index: Int

    @State private var isHovered = false

    var isSelected: Bool {
        project.selectedInteractionID == interaction.id
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color(hex: "0A84FF") : Color(hex: "444444"))
                    .frame(width: 20, height: 20)

                Text("\(index)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(timeString(from: interaction.timestamp))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "F0F0F0"))

                Text("Zoom \(Int(interaction.zoomLevel * 100))%")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "888888"))
            }

            Spacer()

            if isHovered {
                Menu {
                    Button(action: {
                        project.currentTime = interaction.timestamp
                        project.selectedInteractionID = interaction.id
                    }) {
                        Label("Go to Keyframe", systemImage: "arrow.right.circle")
                    }

                    Button(action: {
                        duplicateInteraction()
                    }) {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }

                    Divider()

                    Button(role: .destructive, action: {
                        project.removeInteraction(id: interaction.id)
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "666666"))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20, height: 20)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            isSelected
                ? Color(hex: "0A84FF").opacity(0.15)
                : (isHovered ? Color(hex: "2C2C2C") : Color.clear)
        )
        .cornerRadius(6)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            project.selectedInteractionID = interaction.id
        }
    }

    private func timeString(from time: CMTime) -> String {
        let seconds = time.seconds
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let tenths = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", mins, secs, tenths)
    }

    private func duplicateInteraction() {
        let newInteraction = InteractionPoint(
            timestamp: interaction.timestamp,
            position: interaction.position,
            zoomLevel: interaction.zoomLevel,
            transitionDuration: interaction.transitionDuration
        )
        project.interactions.append(newInteraction)
        project.interactions.sort { $0.timestamp.seconds < $1.timestamp.seconds }
        project.selectedInteractionID = newInteraction.id
    }
}
