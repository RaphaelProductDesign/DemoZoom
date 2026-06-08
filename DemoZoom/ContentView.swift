import SwiftUI

struct ContentView: View {
    @StateObject private var project = DemoProject()
    @StateObject private var recorder = ScreenRecorder()
    @State private var showingImportPicker = false
    @State private var showingPreview = false
    @State private var showingExport = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            HSplitView {
                sidebar
                    .frame(width: 220)

                if project.videoURL != nil {
                    HStack(spacing: 0) {
                        // Left: Source video for managing keyframes
                        SourceVideoView(project: project)
                            .frame(maxWidth: .infinity)

                        Divider()
                            .background(Color(hex: "333333"))

                        // Right: Live output preview with zoom effects
                        OutputPreviewView(project: project)
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    emptyState
                }
            }

            if project.videoURL != nil {
                TimelineView(project: project)
            }
        }
        .background(Color(hex: "1A1A1A"))
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task {
                    try? await project.loadVideo(from: url)
                }
            }
        }
        .sheet(isPresented: $showingPreview) {
            if let url = project.videoURL {
                PreviewView(
                    project: project,
                    videoURL: url,
                    isPresented: $showingPreview
                )
            }
        }
        .sheet(isPresented: $showingExport) {
            if let url = project.videoURL {
                ExportProgressView(
                    project: project,
                    videoURL: url,
                    isPresented: $showingExport
                )
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Text("DemoZoom")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "F0F0F0"))

                if project.videoURL != nil {
                    Divider()
                        .frame(height: 20)
                        .background(Color(hex: "404040"))

                    Text("Source Video")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "888888"))

                    Spacer()

                    Divider()
                        .frame(height: 20)
                        .background(Color(hex: "404040"))

                    Text("Output Preview")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "888888"))
                } else {
                    Spacer()
                }
            }

            Spacer()

            if recorder.isRecording {
                Button(action: {
                    Task {
                        try? await recorder.stopRecording()
                    }
                }) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: "FF453A"))
                            .frame(width: 8, height: 8)
                        Text("Stop")
                    }
                }
                .buttonStyle(ToolbarButtonStyle(tint: Color(hex: "FF453A")))
            } else {
                Button("Record") {
                    Task {
                        try? await recorder.fetchAvailableWindows()
                        if let url = try? await recorder.startRecording() {
                            try? await recorder.stopRecording()
                            try? await project.loadVideo(from: url)
                        }
                    }
                }
                .buttonStyle(ToolbarButtonStyle(tint: Color(hex: "FF453A")))
            }

            Button("Import") {
                showingImportPicker = true
            }
            .buttonStyle(ToolbarButtonStyle())

            Button("Preview") {
                showingPreview = true
            }
            .buttonStyle(ToolbarButtonStyle())
            .disabled(project.videoURL == nil || project.interactions.isEmpty)

            Button("Export MP4") {
                showingExport = true
            }
            .buttonStyle(ToolbarButtonStyle(tint: Color(hex: "0A84FF")))
            .disabled(project.videoURL == nil || project.interactions.isEmpty)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Color(hex: "242424"))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            InteractionListView(project: project)
        }
        .background(Color(hex: "1A1A1A"))
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "555555"))

            Text("No video loaded")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(hex: "888888"))

            Text("Record the Simulator or import an existing video")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "555555"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "111111"))
    }

}

struct ToolbarButtonStyle: ButtonStyle {
    var tint: Color = Color(hex: "888888")

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                configuration.isPressed
                    ? tint.opacity(0.2)
                    : Color.clear
            )
            .foregroundColor(tint)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(hex: "404040"), lineWidth: 0.5)
            )
    }
}
