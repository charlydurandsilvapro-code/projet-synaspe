import Foundation
import AVFoundation
import CoreMedia

// MARK: - Simple Beat Detection Engine (Version de test)

/// Version simplifiée du moteur de détection de rythme pour les tests
@available(macOS 14.0, *)
actor SimpleBeatDetectionEngine {
    
    // MARK: - Properties
    private let logger = NeuralLogger.forCategory("SimpleBeatDetectionEngine")
    private let configuration: ProcessingConfiguration
    
    // MARK: - Beat Detection State
    private var detectedBeats: [BeatPoint] = []
    private var estimatedTempo: Float = 0.0
    
    // MARK: - Initialization
    
    init(configuration: ProcessingConfiguration) {
        self.configuration = configuration
        
        logger.info("SimpleBeatDetectionEngine initialisé", metadata: [
            "rhythm_mode": configuration.rhythmMode.rawValue
        ])
    }
    
    // MARK: - Public Interface
    
    /// Détecte les battements dans un buffer audio (version simplifiée)
    func detectBeats(_ buffer: AudioBuffer) async throws -> [BeatPoint] {
        guard configuration.rhythmMode != .disabled else {
            return []
        }
        
        logger.debug("Détection de battements simplifiée", metadata: [
            "buffer_timestamp": buffer.timestamp.seconds,
            "frame_count": buffer.frameCount
        ])
        
        // Analyse simplifiée basée sur l'énergie
        let beatPoints = analyzeEnergyPeaks(buffer)
        
        // Mise à jour de l'historique
        detectedBeats.append(contentsOf: beatPoints)
        
        // Limitation de l'historique
        if detectedBeats.count > 1000 {
            detectedBeats.removeFirst(detectedBeats.count - 1000)
        }
        
        // Estimation simple du tempo
        updateTempoEstimation()
        
        logger.debug("Battements détectés", metadata: [
            "beat_count": beatPoints.count,
            "estimated_tempo": estimatedTempo
        ])
        
        return beatPoints
    }
    
    /// Aligne les points de coupe sur les battements détectés
    func alignCutPoints(_ segments: [AudioSegment]) async throws -> [AudioSegment] {
        guard configuration.rhythmMode != .disabled && !detectedBeats.isEmpty else {
            return segments
        }
        
        logger.debug("Alignement des points de coupe", metadata: [
            "segment_count": segments.count,
            "available_beats": detectedBeats.count
        ])
        
        // Pour cette version simplifiée, on retourne les segments sans modification
        return segments
    }
    
    /// Retourne le tempo estimé actuel
    var currentTempo: Float {
        get async {
            return estimatedTempo
        }
    }
    
    /// Retourne tous les battements détectés
    var allDetectedBeats: [BeatPoint] {
        get async {
            return detectedBeats
        }
    }
    
    // MARK: - Private Implementation
    
    private func analyzeEnergyPeaks(_ buffer: AudioBuffer) -> [BeatPoint] {
        var beatPoints: [BeatPoint] = []
        
        // Analyse simplifiée de l'énergie
        let windowSize = 1024
        let hopSize = 512
        let numWindows = max(1, buffer.frameCount / hopSize)
        
        for windowIndex in 0..<numWindows {
            let startIndex = windowIndex * hopSize
            let endIndex = min(startIndex + windowSize, buffer.frameCount)
            
            // Calcul de l'énergie RMS pour cette fenêtre
            var energy: Float = 0.0
            var sampleCount = 0
            
            for i in startIndex..<endIndex {
                if i < buffer.data.count {
                    let sample = buffer.data[i]
                    energy += sample * sample
                    sampleCount += 1
                }
            }
            
            if sampleCount > 0 {
                energy = sqrt(energy / Float(sampleCount))
                
                // Détection de pic d'énergie simple
                let threshold: Float = 0.1 * getSensitivity(for: configuration.rhythmMode)
                
                if energy > threshold {
                    let timestamp = CMTimeAdd(
                        buffer.timestamp,
                        CMTime(seconds: Double(startIndex) / buffer.sampleRate, preferredTimescale: 600)
                    )
                    
                    let beatPoint = BeatPoint(
                        timestamp: timestamp,
                        strength: energy,
                        type: .kick, // Type par défaut
                        confidence: min(1.0, energy / threshold)
                    )
                    
                    beatPoints.append(beatPoint)
                }
            }
        }
        
        return beatPoints
    }
    
    private func updateTempoEstimation() {
        guard detectedBeats.count >= 4 else { return }
        
        // Calcul simple du tempo basé sur les derniers battements
        let recentBeats = Array(detectedBeats.suffix(10))
        var intervals: [TimeInterval] = []
        
        for i in 1..<recentBeats.count {
            let interval = recentBeats[i].timestamp.seconds - recentBeats[i-1].timestamp.seconds
            if interval > 0.2 && interval < 2.0 {
                intervals.append(interval)
            }
        }
        
        if !intervals.isEmpty {
            let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
            let newTempo = Float(60.0 / averageInterval)
            
            if newTempo >= 60 && newTempo <= 200 {
                estimatedTempo = newTempo
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func getSensitivity(for mode: RhythmMode) -> Float {
        switch mode {
        case .disabled:
            return 0.0
        case .moderate:
            return 1.0
        case .aggressive:
            return 1.5
        }
    }
}

// Alias pour utiliser la version simple dans les tests
typealias BeatDetectionEngine = SimpleBeatDetectionEngine