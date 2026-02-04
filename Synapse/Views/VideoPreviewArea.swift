import SwiftUI
import AVKit

@available(macOS 14.0, *)
struct VideoPreviewArea: View {
    @ObservedObject var viewModel: ProjectViewModel
    @State private var currentTime: Double = 0
    @State private var isPlaying = false
    @State private var showingControls = true
    @State private var controlsTimer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                if viewModel.project.timeline.isEmpty {
                    // Empty State
                    VStack(spacing: 16) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        
                        Text("Aucune vidéo à prévisualiser")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        
                        Text("Importez des vidéos et générez une timeline pour voir l'aperçu")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    // Video Preview
                    ZStack {
                        // Mock Video Player
                        MockVideoPlayerView(
                            segments: viewModel.project.timeline,
                            currentTime: $currentTime,
                            isPlaying: $isPlaying
                        )
                        
                        // Overlay Controls
                        if showingControls {
                            VideoOverlayControls(
                                isPlaying: $isPlaying,
                                currentTime: $currentTime,
                                totalDuration: totalDuration,
                                onSeek: { time in
                                    currentTime = time
                                }
                            )
                            .transition(.opacity)
                        }
                    }
                    .onHover { hovering in
                        if hovering {
                            showControls()
                        }
                    }
                    .onTapGesture {
                        showControls()
                    }
                }
                
                // Aspect Ratio Indicator
                VStack {
                    HStack {
                        Spacer()
                        AspectRatioIndicator(aspectRatio: viewModel.project.aspectRatio)
                    }
                    Spacer()
                }
                .padding()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var totalDuration: Double {
        viewModel.project.timeline.reduce(0) { $0 + $1.timeRange.duration.seconds }
    }
    
    private func showControls() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingControls = true
        }
        
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showingControls = false
            }
        }
    }
}

// MARK: - Mock Video Player
@available(macOS 14.0, *)
struct MockVideoPlayerView: View {
    let segments: [VideoSegment]
    @Binding var currentTime: Double
    @Binding var isPlaying: Bool
    @State private var animationTimer: Timer?
    
    var body: some View {
        ZStack {
            // Gradient background simulating video content
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.3),
                    Color.pink.opacity(0.2),
                    Color.blue.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated elements to simulate video playback
            if isPlaying {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 20, height: 20)
                        .offset(
                            x: cos(currentTime + Double(index)) * 100,
                            y: sin(currentTime + Double(index) * 1.5) * 80
                        )
                        .animation(.linear(duration: 0.1), value: currentTime)
                }
            }
            
            // Current segment info
            if let currentSegment = getCurrentSegment() {
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Segment Actuel")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(currentSegment.sourceURL.lastPathComponent)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                            
                            Text("Qualité: \(String(format: "%.1f", currentSegment.qualityScore))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding()
                }
            }
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            if isPlaying {
                currentTime += 0.1
                if currentTime >= totalDuration {
                    currentTime = 0
                    isPlaying = false
                }
            }
        }
    }
    
    private var totalDuration: Double {
        segments.reduce(0) { $0 + $1.timeRange.duration.seconds }
    }
    
    private func getCurrentSegment() -> VideoSegment? {
        var accumulatedTime: Double = 0
        
        for segment in segments {
            let segmentDuration = segment.timeRange.duration.seconds
            if currentTime >= accumulatedTime && currentTime < accumulatedTime + segmentDuration {
                return segment
            }
            accumulatedTime += segmentDuration
        }
        
        return segments.first
    }
}

// MARK: - Video Overlay Controls
@available(macOS 14.0, *)
struct VideoOverlayControls: View {
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    let totalDuration: Double
    let onSeek: (Double) -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            // Bottom Controls
            VStack(spacing: 12) {
                // Progress Bar
                VStack(spacing: 4) {
                    HStack {
                        Text(formatTime(currentTime))
                            .font(.caption)
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        Text(formatTime(totalDuration))
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Track
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 4)
                            
                            // Progress
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: geometry.size.width * (currentTime / max(totalDuration, 1)),
                                    height: 4
                                )
                        }
                        .onTapGesture { location in
                            let progress = location.x / geometry.size.width
                            let newTime = progress * totalDuration
                            onSeek(newTime)
                        }
                    }
                    .frame(height: 4)
                }
                
                // Control Buttons
                HStack(spacing: 20) {
                    Button(action: { onSeek(max(0, currentTime - 10)) }) {
                        Image(systemName: "gobackward.10")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { isPlaying.toggle() }) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { onSeek(min(totalDuration, currentTime + 10)) }) {
                        Image(systemName: "goforward.10")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Aspect Ratio Indicator
@available(macOS 14.0, *)
struct AspectRatioIndicator: View {
    let aspectRatio: CGSize
    
    var body: some View {
        Text(aspectRatioText)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .foregroundStyle(.secondary)
    }
    
    private var aspectRatioText: String {
        let ratio = aspectRatio.width / aspectRatio.height
        
        if abs(ratio - 16/9) < 0.1 {
            return "16:9"
        } else if abs(ratio - 9/16) < 0.1 {
            return "9:16"
        } else if abs(ratio - 4/3) < 0.1 {
            return "4:3"
        } else if abs(ratio - 1) < 0.1 {
            return "1:1"
        } else {
            return String(format: "%.1f:1", ratio)
        }
    }
}