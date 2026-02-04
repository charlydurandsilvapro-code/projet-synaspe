import SwiftUI
import AVFoundation

/// Vue de clip intelligent avec trim handles et interactions
@available(macOS 14.0, *)
struct ClipView: View {
    let segment: VideoSegment
    let engine: TimelineEngine
    let thumbnail: CGImage?
    
    @State private var isHovered = false
    @State private var trimStartDrag: CGFloat = 0
    @State private var trimEndDrag: CGFloat = 0
    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false
    
    private let minWidth: CGFloat = 20 // Largeur minimale d'un clip
    
    var isSelected: Bool {
        engine.selection.contains(segment.id)
    }
    
    var clipWidth: CGFloat {
        max(minWidth, segment.timeRange.duration.seconds * engine.zoomLevel)
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            // 1. Contenu visuel
            clipContent
            
            // 2. Bordure de sélection
            if isSelected {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
            }
            
            // 3. Trim handles (visible au survol ou si sélectionné)
            if isHovered || isSelected {
                trimHandles
            }
            
            // 4. Info overlay
            if clipWidth > 60 {
                infoOverlay
            }
        }
        .frame(width: clipWidth, height: 80)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            handleTap()
        }
        // Animation fluide lors des changements de taille
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: segment.timeRange.duration.seconds)
    }
    
    // MARK: - Clip Content
    
    private var clipContent: some View {
        ZStack {
            // Fond avec dégradé
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.2),
                            Color(white: 0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Thumbnail si disponible
            if let thumbnail = thumbnail {
                Image(decorative: thumbnail, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: clipWidth, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .opacity(0.6)
            }
            
            // Pattern de lignes pour identifier visuellement
            GeometryReader { geo in
                Path { path in
                    let spacing: CGFloat = 20
                    var x: CGFloat = 0
                    while x < geo.size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                        x += spacing
                    }
                }
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
            }
        }
    }
    
    // MARK: - Trim Handles
    
    private var trimHandles: some View {
        HStack(spacing: 0) {
            // Handle de début
            TrimHandle(edge: .leading, isActive: isDraggingStart)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDraggingStart {
                                isDraggingStart = true
                                engine.beginEdit(segmentId: segment.id, type: .trimStart)
                            }
                            
                            let delta = value.translation.width
                            trimStartDrag = delta
                            engine.updateEdit(delta: delta)
                        }
                        .onEnded { _ in
                            isDraggingStart = false
                            trimStartDrag = 0
                            engine.commitEdit()
                        }
                )
            
            Spacer()
            
            // Handle de fin
            TrimHandle(edge: .trailing, isActive: isDraggingEnd)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDraggingEnd {
                                isDraggingEnd = true
                                engine.beginEdit(segmentId: segment.id, type: .trimEnd)
                            }
                            
                            let delta = value.translation.width
                            trimEndDrag = delta
                            engine.updateEdit(delta: delta)
                        }
                        .onEnded { _ in
                            isDraggingEnd = false
                            trimEndDrag = 0
                            engine.commitEdit()
                        }
                )
        }
    }
    
    // MARK: - Info Overlay
    
    private var infoOverlay: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Nom du fichier
            Text(segment.sourceURL.lastPathComponent)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 2)
            
            // Durée
            Text(formatDuration(segment.timeRange.duration.seconds))
                .font(.system(size: 9, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
                .shadow(color: .black.opacity(0.5), radius: 2)
            
            Spacer()
            
            // Score de qualité
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { index in
                    Image(systemName: index < Int(segment.qualityScore * 5) ? "star.fill" : "star")
                        .font(.system(size: 7))
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding(6)
    }
    
    // MARK: - Actions
    
    private func handleTap() {
        if NSEvent.modifierFlags.contains(.command) {
            engine.toggleSelection(segment.id)
        } else {
            engine.selectOnly(segment.id)
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Trim Handle Component

@available(macOS 14.0, *)
struct TrimHandle: View {
    enum Edge {
        case leading, trailing
    }
    
    let edge: Edge
    let isActive: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        ZStack {
            // Handle visible
            RoundedRectangle(cornerRadius: 2)
                .fill(isActive ? Color.purple : Color.white.opacity(0.9))
                .frame(width: 4, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Color.black.opacity(0.3), lineWidth: 1)
                )
            
            // Zone de hit étendue (invisible)
            Rectangle()
                .fill(Color.clear)
                .frame(width: 12, height: 80)
        }
        .scaleEffect(isHovered || isActive ? 1.2 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovered)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isActive)
        .onHover { hovering in
            isHovered = hovering
        }
        .cursor(.resizeLeftRight)
    }
}

// MARK: - Custom Cursor Modifier

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onContinuousHover { phase in
            switch phase {
            case .active:
                cursor.push()
            case .ended:
                NSCursor.pop()
            }
        }
    }
}
