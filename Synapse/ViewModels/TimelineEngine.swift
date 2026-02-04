import SwiftUI
import Observation
import CoreMedia
import AVFoundation

/// Moteur de timeline réactif avec système d'interconnexion magnétique
@available(macOS 14.0, *)
@Observable
final class TimelineEngine {
    
    // MARK: - Source de vérité unique
    
    /// Liste ordonnée des segments vidéo (ordre = position temporelle)
    var segments: [VideoSegment] = []
    
    /// Sélection multiple possible
    var selection: Set<UUID> = []
    
    /// Niveau de zoom (pixels par seconde)
    var zoomLevel: CGFloat = 10.0
    
    /// Position de la tête de lecture (en secondes)
    var playheadPosition: TimeInterval = 0.0
    
    /// Mode d'édition actif
    var editMode: EditMode = .select
    
    // MARK: - État transitoire (pour performances)
    
    /// Segment en cours de modification (avant commit)
    var temporaryEdit: TemporaryEdit?
    
    /// Segment en cours de déplacement
    var draggingSegment: DraggingState?
    
    // MARK: - Calculated Properties
    
    /// Durée totale de la timeline
    var totalDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.timeRange.duration.seconds }
    }
    
    /// Largeur totale de la timeline en pixels
    var totalWidth: CGFloat {
        totalDuration * zoomLevel
    }
    
    // MARK: - Position Calculation (Interconnexion)
    
    /// Calcule la position X d'un segment basée sur les segments précédents
    func position(for segmentId: UUID) -> CGFloat {
        guard let index = segments.firstIndex(where: { $0.id == segmentId }) else {
            return 0
        }
        
        // Somme cumulative des durées précédentes
        let cumulativeDuration = segments[0..<index].reduce(0.0) { 
            $0 + $1.timeRange.duration.seconds 
        }
        
        return cumulativeDuration * zoomLevel
    }
    
    /// Calcule l'offset temporel d'un segment (temps de début)
    func timeOffset(for segmentId: UUID) -> TimeInterval {
        guard let index = segments.firstIndex(where: { $0.id == segmentId }) else {
            return 0
        }
        
        return segments[0..<index].reduce(0.0) { 
            $0 + $1.timeRange.duration.seconds 
        }
    }
    
    /// Largeur d'un segment en pixels
    func width(for segment: VideoSegment) -> CGFloat {
        segment.timeRange.duration.seconds * zoomLevel
    }
    
    // MARK: - Editing Operations (Ripple Edit)
    
    /// Modifie la durée d'un segment (propagation automatique)
    func trimSegment(id: UUID, startDelta: TimeInterval = 0, endDelta: TimeInterval = 0) {
        guard let index = segments.firstIndex(where: { $0.id == id }) else { return }
        
        var segment = segments[index]
        let originalDuration = segment.timeRange.duration.seconds
        
        // Calcul de la nouvelle durée
        let newStart = max(0, segment.timeRange.start.seconds + startDelta)
        let newDuration = max(0.1, originalDuration - startDelta + endDelta)
        
        // Mise à jour du segment
        segment.timeRange = CMTimeRangeMake(
            start: CMTime(seconds: newStart, preferredTimescale: 600),
            duration: CMTime(seconds: newDuration, preferredTimescale: 600)
        )
        
        segments[index] = segment
        
        // La propagation est automatique grâce au recalcul de position()
    }
    
    /// Déplace un segment vers une nouvelle position (réarrangement)
    func moveSegment(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              segments.indices.contains(sourceIndex),
              segments.indices.contains(destinationIndex) else {
            return
        }
        
        let segment = segments.remove(at: sourceIndex)
        segments.insert(segment, at: destinationIndex)
    }
    
    /// Déplace un segment par ID
    func moveSegment(id: UUID, to destinationIndex: Int) {
        guard let sourceIndex = segments.firstIndex(where: { $0.id == id }) else {
            return
        }
        moveSegment(from: sourceIndex, to: destinationIndex)
    }
    
    /// Supprime un segment (les suivants se décalent automatiquement)
    func removeSegment(id: UUID) {
        segments.removeAll { $0.id == id }
        selection.remove(id)
    }
    
    /// Ajoute un segment à la fin
    func appendSegment(_ segment: VideoSegment) {
        segments.append(segment)
    }
    
    /// Insère un segment à une position donnée
    func insertSegment(_ segment: VideoSegment, at index: Int) {
        segments.insert(segment, at: min(index, segments.count))
    }
    
    // MARK: - Selection Management
    
    func toggleSelection(_ id: UUID) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }
    
    func selectOnly(_ id: UUID) {
        selection = [id]
    }
    
    func clearSelection() {
        selection.removeAll()
    }
    
    func selectAll() {
        selection = Set(segments.map(\.id))
    }
    
    // MARK: - Zoom Controls
    
    func zoomIn() {
        zoomLevel = min(zoomLevel * 1.2, 50.0)
    }
    
    func zoomOut() {
        zoomLevel = max(zoomLevel / 1.2, 2.0)
    }
    
    func resetZoom() {
        zoomLevel = 10.0
    }
    
    func fitToView(viewWidth: CGFloat) {
        guard totalDuration > 0 else { return }
        zoomLevel = viewWidth / totalDuration * 0.9 // 90% pour les marges
    }
    
    // MARK: - Playhead Control
    
    func movePlayhead(to time: TimeInterval) {
        playheadPosition = max(0, min(time, totalDuration))
    }
    
    func movePlayheadToSegment(_ id: UUID) {
        playheadPosition = timeOffset(for: id)
    }
    
    // MARK: - Temporary Edit Management
    
    func beginEdit(segmentId: UUID, type: EditType) {
        guard let segment = segments.first(where: { $0.id == segmentId }) else { return }
        temporaryEdit = TemporaryEdit(
            segmentId: segmentId,
            originalSegment: segment,
            type: type
        )
    }
    
    func updateEdit(delta: CGFloat) {
        guard let edit = temporaryEdit else { return }
        
        let timeDelta = delta / zoomLevel
        
        switch edit.type {
        case .trimStart:
            trimSegment(id: edit.segmentId, startDelta: timeDelta)
        case .trimEnd:
            trimSegment(id: edit.segmentId, endDelta: timeDelta)
        case .move:
            // Géré par le drag & drop
            break
        }
    }
    
    func commitEdit() {
        temporaryEdit = nil
    }
    
    func cancelEdit() {
        guard let edit = temporaryEdit,
              let index = segments.firstIndex(where: { $0.id == edit.segmentId }) else {
            return
        }
        
        // Restaurer l'original
        segments[index] = edit.originalSegment
        temporaryEdit = nil
    }
    
    // MARK: - Snap to Beat (Magnétisme musical)
    
    func snapToNearestBeat(time: TimeInterval, beatGrid: [TimeInterval]) -> TimeInterval {
        guard !beatGrid.isEmpty else { return time }
        
        // Trouve le beat le plus proche
        let closestBeat = beatGrid.min(by: { abs($0 - time) < abs($1 - time) }) ?? time
        
        // Snap si proche de moins de 0.1 seconde
        if abs(closestBeat - time) < 0.1 {
            return closestBeat
        }
        
        return time
    }
}

// MARK: - Supporting Types

extension TimelineEngine {
    enum EditMode {
        case select
        case trim
        case split
        case ripple
    }
    
    enum EditType {
        case trimStart
        case trimEnd
        case move
    }
    
    struct TemporaryEdit {
        let segmentId: UUID
        let originalSegment: VideoSegment
        let type: EditType
    }
    
    struct DraggingState {
        let segmentId: UUID
        var currentIndex: Int
        var targetIndex: Int?
        var offset: CGFloat = 0
    }
}

