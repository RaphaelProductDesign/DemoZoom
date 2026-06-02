# DemoZoom

A macOS SwiftUI app for creating polished product demo videos with automatic smart zoom.

## Features

- **Import or Record**: Import existing videos or record iOS Simulator directly
- **Smart Zoom**: Mark up to 10 interaction points with custom zoom levels (0-200%)
- **Smooth Transitions**: 0.4s easeInOutCubic transitions between zoom zones
- **Real-time Preview**: Preview your video with zoom effects before export
- **Export to MP4**: Export high-quality MP4 videos preserving original resolution

## Requirements

- macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

## Project Structure

```
DemoZoom/
├── DemoZoomApp.swift           # App entry point
├── ContentView.swift            # Main app layout
├── Models/
│   ├── InteractionPoint.swift   # Interaction point data model
│   └── DemoProject.swift        # Project state management
├── Views/
│   ├── VideoEditorView.swift    # Video editor with tap overlay
│   ├── InteractionListView.swift # Sidebar list of interactions
│   ├── VideoScrubber.swift      # Video scrubber controls
│   ├── PreviewView.swift        # Preview with zoom applied
│   └── ExportProgressView.swift # Export progress sheet
├── Services/
│   ├── ScreenRecorder.swift     # ScreenCaptureKit integration
│   ├── VideoProcessor.swift     # Video composition & export
│   └── ZoomCompositor.swift     # Custom AVVideoCompositing
└── Utils/
    ├── EasingFunctions.swift    # easeInOutCubic interpolation
    └── ColorExtension.swift     # Hex color support
```

## Building

### Option 1: Xcode Project
1. Create a new macOS app in Xcode
2. Set minimum deployment target to macOS 14.0
3. Add all files from `DemoZoom/` folder to your project
4. Enable Screen Recording capability in Signing & Capabilities
5. Build and run

### Option 2: Swift Package Manager
```bash
swift build
swift run DemoZoom
```

## Permissions

The app requires Screen Recording permission to capture the iOS Simulator window. You'll be prompted to grant this permission on first launch.

## Usage

1. **Record or Import**: Click "Record" to capture the iOS Simulator, or "Import" to load an existing video
2. **Mark Interactions**: Click directly on the video to place interaction points at key moments
3. **Adjust Zoom**: Select an interaction point in the sidebar and adjust the zoom slider (0-200%)
4. **Preview**: Click "Preview" to see your video with zoom transitions applied
5. **Export**: Click "Export MP4" to save your final demo video

## Design

The UI follows a dark, tool-like aesthetic inspired by Final Cut Pro:
- **Background**: `#1A1A1A`
- **Surface**: `#242424`
- **Accent**: `#0A84FF` (macOS blue)
- Clean typography with SF Pro
- Minimal, focused interface

## Architecture Highlights

- **AVFoundation**: Video playback and export
- **ScreenCaptureKit**: Native Simulator window capture
- **Custom Compositor**: `ZoomCompositor` implements `AVVideoCompositing` for real-time zoom/pan
- **SwiftUI**: Modern declarative UI
- **Combine**: Reactive state management with `@ObservedObject` and `@Published`

## Constraints (v1)

- Max 10 interaction points per video
- 30fps recording and export
- No audio support
- No rotation or perspective transforms
- No undo/redo
- No project save/load (session only)

## License

MIT
