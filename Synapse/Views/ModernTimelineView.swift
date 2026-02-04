import SwiftUI

@available(macOS 14.0, *)
struct ModernTimelineView: View {
    @ObservedObject var viewModel: ProjectViewModel
    @State private var timelineScale: CGFloat = 1.0
    @State private var timelineOffset: CGFloat = 0
    @State private var playheadPosition: CGFloat = 0
    @State private var selectedSegmentId: UUID?
    @State private var draggedSegment: VideoSegment?
    
    private let segmentHeight: CGFloat = 80
    private let trackHeight: CGFloat = 100
    private let timelineHeight: CGFloat = 200
    
    var body: some View {
        VStack(spacing: 0) {
            // Timeline Header
            TimelineHeaderView(
                scale: $timelineScale,
                offset: $timelineOffset,
                onZoomIn: { timelineScale = min(timelineScale * 1.2, 5.0) },
                onZoomOut: { timelineScale = max(timelineScale / 1.2, 0.2) },
                onReset: { 
                    timelineScale = 1.0
                    timelineOffset = 0
                }
            )
            
            Divider()
            
            // Timeline Content
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    // Background Grid
                    TimelineGridView(scale: timelineScale)
                    
                    // Video Track
                    VStack(spacing: 8) {
                        // Track Header
                        HStack {
                            Text("Vidéo")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .frame(width: 80, alignment: .leading)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        .frame(height: 30)
                        .background(.ultraThinMaterial)
                        
                        // Video Segments
                        ZStack(alignment: .leading) {
                            // Track Background
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: trackHeight)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            
                            // Segments
                            HStack(spacing: 2) {
                                ForEach(viewModel.project.timeline, id: \.id) { segment in
                                    TimelineSegmentView(
                                        segment: segment,
                                        scale: timelineScale,
                                        isSelected: selectedSegmentId == segment.id,
                                        thumbnail: viewModel.thumbnails[segment.id],
                                        onSelect: { selectedSegmentId = segment.id },
                                        onDelete: { viewModel.removeSegment(segment) }
                                    )
                                    .onDrag {
                                        draggedSegment = segment
                                        return NSItemProvider(object: segment.id.uuidString as NSString)
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                        .frame(height: trackHeight)
                        .padding(.horizontal)
                        
                        // Audio Track
                        if let audioTrack = viewModel.project.musicTrack {
                            VStack(spacing: 8) {
                                // Track Header
                                HStack {
                                    Text("Audio")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                        .frame(width: 80, alignment: .leading)
                                    
                                    Text("\(Int(audioTrack.bpm)) BPM")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .frame(height: 30)
                                .background(.ultraThinMaterial)
                                
                                // Audio Waveform
                                AudioWaveformView(
                                    audioTrack: audioTrack,
                                    scale: timelineScale
                                )
                                .frame(height: 60)
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Playhead
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2)
                        .offset(x: playheadPosition)
                        .animation(.easeInOut(duration: 0.1), value: playheadPosition)
                }
                .frame(
                    width: max(1000, CGFloat(totalTimelineDuration) * timelineScale * 10),
                    height: timelineHeight
                )
            }
            .frame(height: timelineHeight)
            .background(Color(red: 0.08, green: 0.08, blue: 0.09))
            
            // Timeline Footer
            TimelineFooterView(viewModel: viewModel)
        }
    }
    
    private var totalTimelineDuration: Double {
        viewModel.project.timeline.reduce(0) { $0 + $1.timeRange.duration.seconds }
    }
}

// MARK: - Timeline Header
@available(macOS 14.0, *)
struct TimelineHeaderView: View {
    @Binding var scale: CGFloat
    @Binding var offset: CGFloat
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onReset: () -> Void
    
    var body: some View {
        HStack {
            // Timeline Controls
            HStack(spacing: 8) {
                Button(action: onZoomOut) {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("Dézoomer")
                
                Text("\(Int(scale * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(width: 40)
                    .foregroundStyle(.secondary)
                
                Button(action: onZoomIn) {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("Zoomer")
                
                Button(action: onReset) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("Réinitialiser le zoom")
            }
            
            Spacer()
            
            // Timeline Info
            HStack(spacing: 16) {
                Text("Segments: \(0)")  // TODO: Get actual count
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("Durée: 00:00")  // TODO: Get actual duration
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Timeline Grid
@available(macOS 14.0, *)
struct TimelineGridView: View {
    let scale: CGFloat
    
    var body: some View {
        Canvas { context, size in
            let gridSpacing = 50 * scale
            let lineColor = Color.white.opacity(0.1)
            
            // Vertical grid lines (time markers)
            var x: CGFloat = 0
            while x < size.width {
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(lineColor),
                    lineWidth: 0.5
                )
                x += gridSpacing
            }
            
            // Horizontal grid lines
            let horizontalSpacing: CGFloat = 50
            var y: CGFloat = 0
            while y < size.height {
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    },
                    with: .color(lineColor),
                    lineWidth: 0.5
                )
                y += horizontalSpacing
            }
        }
    }
}

// MARK: - Timeline Segment
@available(macOS 14.0, *)
struct TimelineSegmentView: View {
    let segment: VideoSegment
    let scale: CGFloat
    let isSelected: Bool
    let thumbnail: CGImage?
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    private var segmentWidth: CGFloat {
        CGFloat(segment.timeRange.duration.seconds) * scale * 10
    }
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.8),
                            Color.pink.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isSelected ? Color.white : Color.white.opacity(0.3),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
            
            // Thumbnail
            if let thumbnail = thumbnail {
                Image(thumbnail, scale: 1.0, label: Text("Thumbnail"))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .opacity(0.7)
            }
            
            // Content
            VStack(spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(segment.sourceURL.lastPathComponent)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        Text("Q: \(String(format: "%.1f", segment.qualityScore))")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    if isHovered {
                        Button(action: onDelete) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .background(Color.red, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                // Tags
                if !segment.tags.isEmpty {
                    HStack {
                        ForEach(segment.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .foregroundStyle(.white)
                        }
                        Spacer()
                    }
                }
            }
            .padding(6)
        }
        .frame(width: max(segmentWidth, 80), height: 70)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Audio Waveform
@available(macOS 14.0, *)
struct AudioWaveformView: View {
    let audioTrack: AudioTrack
    let scale: CGFloat
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Track Background
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.green.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.green.opacity(0.4), lineWidth: 1)
                )
            
            // Waveform
            Canvas { context, size in
                let waveformColor = Color.green
                let segmentWidth = size.width / CGFloat(audioTrack.energyProfile.count)
                
                for (index, energySegment) in audioTrack.energyProfile.enumerated() {
                    let x = CGFloat(index) * segmentWidth
                    let amplitude = CGFloat(energySegment.rmsAmplitude)
                    let height = size.height * amplitude
                    
                    context.fill(
                        Path { path in
                            path.addRect(CGRect(
                                x: x,
                                y: (size.height - height) / 2,
                                width: segmentWidth - 1,
                                height: height
                            ))
                        },
                        with: .color(waveformColor.opacity(0.8))
                    )
                }
                
                // Beat markers
                for beat in audioTrack.beatGrid {
                    let x = CGFloat(beat.timestamp) * scale * 10
                    if x < size.width {
                        context.stroke(
                            Path { path in
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: size.height))
                            },
                            with: .color(beat.isDownbeat ? Color.yellow : Color.white.opacity(0.5)),
                            lineWidth: beat.isDownbeat ? 2 : 1
                        )
                    }
                }
            }
            
            // Audio Info
            VStack {
                HStack {
                    Text(audioTrack.url.lastPathComponent)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    
                    Spacer()
                }
                Spacer()
            }
            .padding(6)
        }
    }
}

// MARK: - Timeline Footer
@available(macOS 14.0, *)
struct TimelineFooterView: View {
    @ObservedObject var viewModel: ProjectViewModel
    
    var body: some View {
        HStack {
            // Quick Actions
            HStack(spacing: 8) {
                Button("Tout sélectionner") {
                    // TODO: Select all segments
                }
                .buttonStyle(.plain)
                .font(.caption)
                
                Button("Supprimer sélection") {
                    // TODO: Delete selected segments
                }
                .buttonStyle(.plain)
                .font(.caption)
                
                Button("Optimiser") {
                    Task {
                        await viewModel.optimizeForPlatform()
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
            }
            
            Spacer()
            
            // Timeline Stats
            HStack(spacing: 16) {
                Text("Segments: \(viewModel.project.timeline.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("Durée totale: \(formatDuration(totalDuration))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
    
    private var totalDuration: Double {
        viewModel.project.timeline.reduce(0) { $0 + $1.timeRange.duration.seconds }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}