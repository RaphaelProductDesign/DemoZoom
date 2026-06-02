import SwiftUI
import AVFoundation

struct ExportProgressView: View {
    @ObservedObject var project: DemoProject
    let videoURL: URL
    @Binding var isPresented: Bool

    @State private var progress: Double = 0
    @State private var isExporting = false
    @State private var isComplete = false
    @State private var error: String?
    @State private var outputURL: URL?

    var body: some View {
        VStack(spacing: 24) {
            if isExporting {
                VStack(spacing: 16) {
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(Color(hex: "0A84FF"))
                        .frame(width: 300)

                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "F0F0F0"))

                    Text("Exporting video...")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "888888"))
                }
            } else if isComplete {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "30D158"))

                    Text("Export Complete")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "F0F0F0"))

                    if let outputURL = outputURL {
                        Button("Show in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([outputURL])
                        }
                        .buttonStyle(ToolbarButtonStyle(tint: Color(hex: "0A84FF")))
                    }

                    Button("Done") {
                        isPresented = false
                    }
                    .buttonStyle(ToolbarButtonStyle())
                }
            } else if let error = error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "FF453A"))

                    Text("Export Failed")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "F0F0F0"))

                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "888888"))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)

                    Button("Close") {
                        isPresented = false
                    }
                    .buttonStyle(ToolbarButtonStyle())
                }
            } else {
                VStack(spacing: 16) {
                    Text("Ready to Export")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "F0F0F0"))

                    Text("Export your demo video as MP4")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "888888"))

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            isPresented = false
                        }
                        .buttonStyle(ToolbarButtonStyle())

                        Button("Export") {
                            Task {
                                await startExport()
                            }
                        }
                        .buttonStyle(ToolbarButtonStyle(tint: Color(hex: "0A84FF")))
                    }
                }
            }
        }
        .padding(40)
        .frame(width: 500, height: 300)
        .background(Color(hex: "1A1A1A"))
    }

    private func startExport() async {
        isExporting = true

        do {
            let asset = AVAsset(url: videoURL)
            let processor = VideoProcessor()

            let composition = try await processor.generateComposition(
                for: asset,
                interactions: project.interactions,
                videoSize: project.videoSize
            )

            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.mpeg4Movie]
            savePanel.nameFieldStringValue = "demo-\(Date().timeIntervalSince1970).mp4"

            let response = await savePanel.beginSheetModal(for: NSApp.keyWindow!)

            guard response == .OK, let url = savePanel.url else {
                await MainActor.run {
                    isExporting = false
                    isPresented = false
                }
                return
            }

            try await processor.exportVideo(
                asset: asset,
                composition: composition,
                outputURL: url
            ) { p in
                Task { @MainActor in
                    progress = p
                }
            }

            await MainActor.run {
                isExporting = false
                isComplete = true
                outputURL = url
            }
        } catch {
            await MainActor.run {
                isExporting = false
                self.error = error.localizedDescription
            }
        }
    }
}
