import Foundation
import AVFoundation
import SoundAnalysis
import Accelerate
import Vision
import SwiftUI

@available(macOS 14.0, *)
@MainActor
public class NeuralAutoCutEngine: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var progress: Float = 0.0
    @Published public var status: ProcessingStatus = .idle
    @Published public var statistics: EditStatistics?
    @Published public var currentTask: String = ""
    
    // MARK: - Private Components
    private let audioAnalysisPipeline: AudioAnalysisPipeline
    private let visionAnalysisEngine: VisionAnalysisEngine
    private let compositionBuilder: CompositionBuilder
    private let logger: NeuralLogger
    
    // MARK: - Configuration
    private var currentConfiguration: ProcessingConfiguration?
    private var processingTask: Task<Void, Never>?
    
    public init() {
        self.logger = NeuralLogger(category: "NeuralAutoCutEngine")
        self.audioAnalysisPipeline = AudioAnalysisPipeline()
        
        // Configuration par défaut pour l'initialisation
        let defaultConfig = ProcessingConfiguration()
        self.visionAnalysisEngine = VisionAnalysisEngine(configuration: defaultConfig)
        self.compositionBuilder = CompositionBuilder(configuration: defaultConfig)
        
        logger.info("Moteur Neural Auto-Cut initialisé")
    }
    
    // MARK: - Public Interface
    
    /// Traite une vidéo avec le moteur Neural Auto-Cut
    public func processVideo(
        asset: AVAsset,
        configuration: ProcessingConfiguration
    ) async throws -> EditResult {
        
        guard status == .idle else {
            throw NeuralAutoCutError.processingInProgress
        }
        
        logger.info("Démarrage du traitement Neural Auto-Cut")
        
        status = .processing
        progress = 0.0
        currentConfiguration = configuration
        statistics = nil
        
        do {
            let result = try await performProcessing(asset: asset, configuration: configuration)
            
            status = .completed
            progress = 1.0
            statistics = result.statistics
            currentTask = "Traitement terminé avec succès"
            
            logger.info("Traitement Neural Auto-Cut terminé avec succès")
            return result
            
        } catch {
            status = .failed(error)
            currentTask = "Erreur : \(error.localizedDescription)"
            logger.error("Échec du traitement Neural Auto-Cut : \(error)")
            throw error
        }
    }
    
    /// Génère un aperçu des segments sans créer la composition finale
    public func previewSegments(
        asset: AVAsset,
        configuration: ProcessingConfiguration
    ) async throws -> [PreviewSegment] {
        
        logger.info("Génération d'aperçu des segments")
        
        status = .analyzing
        progress = 0.0
        currentTask = "Analyse pour aperçu..."
        
        do {
            // Analyse audio uniquement pour l'aperçu
            let audioAnalysis = try await audioAnalysisPipeline.analyzeAudio(asset)
            progress = 0.8
            
            // Conversion en segments d'aperçu
            let previewSegments = audioAnalysis.map { analyzedSegment in
                PreviewSegment(
                    id: UUID(),
                    startTime: analyzedSegment.segment.startTime,
                    endTime: analyzedSegment.segment.endTime,
                    qualityScore: analyzedSegment.segment.qualityScore,
                    classification: analyzedSegment.segment.classification,
                    shouldKeep: analyzedSegment.segment.qualityScore > configuration.qualityThreshold,
                    reasoning: generateReasoning(for: analyzedSegment)
                )
            }
            
            progress = 1.0
            status = .idle
            currentTask = ""
            
            logger.info("Aperçu généré : \(previewSegments.count) segments")
            return previewSegments
            
        } catch {
            status = .failed(error)
            currentTask = "Erreur d'aperçu : \(error.localizedDescription)"
            logger.error("Échec de génération d'aperçu : \(error)")
            throw error
        }
    }
    
    /// Annule le traitement en cours
    public func cancelProcessing() {
        guard status == .processing || status == .analyzing else { return }
        
        processingTask?.cancel()
        processingTask = nil
        
        status = .cancelled
        progress = 0.0
        currentTask = "Traitement annulé"
        
        logger.info("Traitement Neural Auto-Cut annulé")
    }
    
    // MARK: - Private Implementation
    
    private func performProcessing(
        asset: AVAsset,
        configuration: ProcessingConfiguration
    ) async throws -> EditResult {
        
        let startTime = Date()
        
        // Phase 1: Analyse Audio (0-60%)
        currentTask = "Analyse audio avancée..."
        let audioAnalysis = try await audioAnalysisPipeline.analyzeAudio(asset)
        progress = 0.6
        
        // Phase 2: Analyse Vidéo (60-80%) - Si activée
        var videoAnalysis: [VideoQualityScore] = []
        if configuration.enableVideoAnalysis {
            currentTask = "Analyse qualité vidéo..."
            let videoStream = await visionAnalysisEngine.analyzeVideoQuality(asset)
            for try await qualityScore in videoStream {
                videoAnalysis.append(qualityScore)
            }
            progress = 0.8
        }
        
        // Phase 3: Construction de la Composition (80-100%)
        currentTask = "Construction de la composition finale..."
        
        // Conversion des segments analysés en segments approuvés
        let approvedSegments = audioAnalysis.map { analyzedSegment in
            ApprovedSegment(
                segment: analyzedSegment.segment,
                sourceAsset: asset,
                originalDuration: analyzedSegment.segment.duration
            )
        }
        
        let composition = try await compositionBuilder.buildComposition(approvedSegments)
        progress = 1.0
        
        // Calcul des statistiques
        let processingTime = Date().timeIntervalSince(startTime)
        let originalDuration = try await asset.load(.duration).seconds
        let finalDuration = composition.timeline.reduce(0) { $0 + $1.duration }
        
        let statistics = EditStatistics(
            originalDuration: originalDuration,
            finalDuration: finalDuration,
            reductionPercentage: Float((originalDuration - finalDuration) / originalDuration * 100),
            segmentsKept: composition.timeline.count,
            segmentsRemoved: audioAnalysis.count - composition.timeline.count,
            qualityScore: calculateAverageQuality(composition.timeline),
            processingTime: processingTime
        )
        
        return EditResult(
            composition: composition.composition,
            audioMix: composition.audioMix,
            statistics: statistics,
            timeline: composition.timeline
        )
    }
    
    private func generateReasoning(for segment: AnalyzedSegment) -> String {
        let classification = segment.segment.classification
        let quality = segment.segment.qualityScore
        
        if classification.dominantType == .speech && quality > 0.7 {
            return "Parole de haute qualité détectée"
        } else if classification.dominantType == .music && quality > 0.6 {
            return "Contenu musical préservé"
        } else if classification.dominantType == .noise || quality < 0.4 {
            return "Bruit ou faible qualité - supprimé"
        } else {
            return "Qualité modérée - évaluation contextuelle"
        }
    }
    
    private func calculateAverageQuality(_ timeline: [TimelineSegment]) -> Float {
        guard !timeline.isEmpty else { return 0.0 }
        return timeline.map { $0.qualityScore }.reduce(0, +) / Float(timeline.count)
    }
}

// MARK: - Supporting Types

public enum ProcessingStatus: Equatable {
    case idle
    case analyzing
    case processing
    case completed
    case cancelled
    case failed(Error)
    
    public static func == (lhs: ProcessingStatus, rhs: ProcessingStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.analyzing, .analyzing), (.processing, .processing),
             (.completed, .completed), (.cancelled, .cancelled):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

public struct PreviewSegment: Identifiable {
    public let id: UUID
    public let startTime: CMTime
    public let endTime: CMTime
    public let qualityScore: Float
    public let classification: AudioClassification
    public let shouldKeep: Bool
    public let reasoning: String
    
    public var duration: TimeInterval {
        endTime.seconds - startTime.seconds
    }
}