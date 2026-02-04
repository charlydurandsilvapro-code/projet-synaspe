import SwiftUI
import UniformTypeIdentifiers

/// Timeline magnétique avec drag & drop et interconnexion
@available(macOS 14.0, *)
struct MagneticTimelineView: View {
    let engine: TimelineEngine
    let thumbnails: [UUID: CGImage]
    
    @State private var scrollOffset: CGFloat = 0
    @State private var dropTargetIndex: Int?
    @State private var draggedSegmentId: UUID?
    
    private let trackHeight: CGFloat = 100
    private let timelineMinWidth: CGFloat = 1000
    
    var body: some View {
        VStack(spacing: 0) {
            // Header avec contrôles
            timelineHeader
            
            Divider()
            
            // Zone de timeline scrollable
            ScrollView(.horizontal, showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    // Grille de fond
                    timelineGrid
                    
                    // Track vidéo avec clips
                    videoTrack
                    
                    // Playhead
                    playhead
                }
                .frame(
                    width: max(timelineMinWidth, engine.totalWidth + 100),
                    height: trackHeight + 40
                )
            }
            .frame(height: trackHeight + 40)
            .background(Color(red: 0.08, green: 0.08, blue: 0.09))
        }
    }
    
    // MARK: - Header
    
    private var timelineHeader: some View {
        HStack(spacing: 12) {
            // Contrôles de zoom
            zoomControls
            
            Divider()
                .frame(height: 20)
            
            // Info timeline
            timelineInfo
            
            Spacer()
            
            // Actions
            timelineActions
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
    
    private var zoomControls: some View {
        HStack(spacing: 8) {
            Button(action: engine.zoomOut) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(TimelineButtonStyle())
            .help("Dézoomer (⌘-)")
            .keyboardShortcut("-", modifiers: .command)
            
            Text("\(Int(engine.zoomLevel * 10))%")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 45)
            
            Button(action: engine.zoomIn) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(TimelineButtonStyle())
            .help("Zoomer (⌘+)")
            .keyboardShortcut("+", modifiers: .command)
            
            Button(action: engine.resetZoom) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(TimelineButtonStyle())
            .help("Réinitialiser (⌘0)")
            .keyboardShortcut("0", modifiers: .command)
        }
    }
    
    private var timelineInfo: some View {
        HStack(spacing: 16) {
            Label {
                Text("\(engine.segments.count)")
                    .font(.system(size: 11, weight: .medium))
            } icon: {
                Image(systemName: "film")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.secondary)
            
            Label {
                Text(formatDuration(engine.totalDuration))
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
            } icon: {
                Image(systemName: "clock")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.secondary)
        }
    }
    
    private var timelineActions: some View {
        HStack(spacing: 8) {
            Button(action: engine.selectAll) {
                Image(systemName: "checkmark.square")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(TimelineButtonStyle())
            .help("Sélectionner tout (⌘A)")
            .keyboardShortcut("a", modifiers: .command)
            
            Button(action: engine.clearSelection) {
                Image(systemName: "xmark.square")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(TimelineButtonStyle())
            .help("Désélectionner tout")
            .disabled(engine.selection.isEmpty)
            
            Button(action: deleteSelected) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(TimelineButtonStyle(isDestructive: true))
            .help("Supprimer (⌫)")
            .disabled(engine.selection.isEmpty)
            .keyboardShortcut(.delete, modifiers: [])
        }
    }
    
    // MARK: - Timeline Grid
    
    private var timelineGrid: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Lignes verticales toutes les secondes
                let secondWidth = engine.zoomLevel
                var x: CGFloat = 0
                var second = 0
                
                while x < size.width {
                    let isMainTick = second % 5 == 0
                    
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    
                    context.stroke(
                        path,
                        with: .color(isMainTick ? .white.opacity(0.15) : .white.opacity(0.05)),
                        lineWidth: isMainTick ? 1 : 0.5
                    )
                    
                    // Labels de temps
                    if isMainTick {
                        let text = Text(formatTimeMarker(TimeInterval(second)))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        
                        context.draw(text, at: CGPoint(x: x + 4, y: 10))
                    }
                    
                    x += secondWidth
                    second += 1
                }
            }
        }
    }
    
    // MARK: - Video Track
    
    private var videoTrack: some View {
        VStack(spacing: 8) {
            // Track header
            HStack {
                Image(systemName: "film.stack")
                    .font(.system(size: 12))
                    .foregroundStyle(.purple)
                
                Text("Vidéo")
                    .font(.system(size: 12, weight: .semibold))
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .cornerRadius(6)
            
            // Clips avec drag & drop
            ZStack(alignment: .leading) {
                // Fond du track
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: trackHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                // Indicateurs de drop
                if let targetIndex = dropTargetIndex {
                    let xPos = calculateDropIndicatorPosition(for: targetIndex)
                    Rectangle()
                        .fill(Color.purple)
                        .frame(width: 3, height: trackHeight)
                        .offset(x: xPos)
                        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: targetIndex)
                }
                
                // Segments
                ForEach(engine.segments) { segment in
                    ClipView(
                        segment: segment,
                        engine: engine,
                        thumbnail: thumbnails[segment.id]
                    )
                    .offset(x: engine.position(for: segment.id))
                    .zIndex(draggedSegmentId == segment.id ? 100 : 1)
                    .draggable(segment.id.uuidString) {
                        // Preview du drag
                        ClipDragPreview(segment: segment, width: engine.width(for: segment))
                    }
                    .dropDestination(for: String.self) { items, location in
                        handleDrop(items: items, segment: segment)
                    } isTargeted: { isTargeted in
                        handleDropTargeted(isTargeted: isTargeted, segment: segment)
                    }
                }
            }
            .frame(height: trackHeight)
            .padding(.horizontal, 8)
        }
        .padding(.top, 12)
    }
    
    // MARK: - Playhead
    
    private var playhead: some View {
        ZStack {
            // Ligne verticale
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.red, .red.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2)
            
            // Tête
            VStack(spacing: 0) {
                Triangle()
                    .fill(Color.red)
                    .frame(width: 12, height: 8)
                
                Spacer()
            }
        }
        .offset(x: engine.playheadPosition * engine.zoomLevel - 1)
        .animation(.easeInOut(duration: 0.1), value: engine.playheadPosition)
        .allowsHitTesting(false)
    }
    
    // MARK: - Drag & Drop Logic
    
    private func handleDrop(items: [String], segment: VideoSegment) -> Bool {
        guard let draggedIdString = items.first,
              let draggedId = UUID(uuidString: draggedIdString),
              let targetIndex = engine.segments.firstIndex(where: { $0.id == segment.id }) else {
            return false
        }
        
        engine.moveSegment(id: draggedId, to: targetIndex)
        dropTargetIndex = nil
        draggedSegmentId = nil
        return true
    }
    
    private func handleDropTargeted(isTargeted: Bool, segment: VideoSegment) {
        if isTargeted {
            dropTargetIndex = engine.segments.firstIndex(where: { $0.id == segment.id })
        } else if dropTargetIndex == engine.segments.firstIndex(where: { $0.id == segment.id }) {
            dropTargetIndex = nil
        }
    }
    
    private func calculateDropIndicatorPosition(for index: Int) -> CGFloat {
        guard engine.segments.indices.contains(index) else {
            return 0
        }
        return engine.position(for: engine.segments[index].id)
    }
    
    // MARK: - Actions
    
    private func deleteSelected() {
        for id in engine.selection {
            engine.removeSegment(id: id)
        }
    }
    
    // MARK: - Helpers
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let frames = Int((seconds - Double(Int(seconds))) * 30)
        return String(format: "%02d:%02d:%02d", mins, secs, frames)
    }
    
    private func formatTimeMarker(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Supporting Views

@available(macOS 14.0, *)
struct ClipDragPreview: View {
    let segment: VideoSegment
    let width: CGFloat
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.purple.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.purple, lineWidth: 2)
                )
            
            Text(segment.sourceURL.lastPathComponent)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(4)
        }
        .frame(width: max(60, width), height: 60)
        .shadow(color: .black.opacity(0.5), radius: 10, y: 5)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Custom Button Style

struct TimelineButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isDestructive ? .red : .primary)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? Color.white.opacity(0.1) : Color.white.opacity(0.05))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
