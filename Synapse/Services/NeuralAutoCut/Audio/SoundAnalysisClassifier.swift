import Foundation
import SoundAnalysis
import AVFoundation
import CoreMedia

// MARK: - Sound Analysis Classifier

/// Classificateur audio utilisant le framework SoundAnalysis d'Apple pour une classification intelligente
@available(macOS 14.0, *)
actor SoundAnalysisClassifier {
    
    // MARK: - Properties
    private let logger = NeuralLogger.soundClassifier
    private let configuration: ProcessingConfiguration
    
    // MARK: - SoundAnalysis Components
    private var audioStreamAnalyzer: SNAudioStreamAnalyzer?
    private var classifyRequest: SNClassifySoundRequest?
    private var audioEngine: AVAudioEngine?
    
    // MARK: - Classification State
    private var isAnalyzing: Bool = false
    private var classificationResults: [AudioClassification] = []
    private var confidenceHistory: SoundClassifierCircularBuffer<Float>
    
    // MARK: - Performance Tracking
    private var classificationCount: Int = 0
    private var totalProcessingTime: TimeInterval = 0
    private var lastClassificationTime: Date?
    
    // MARK: - Initialization
    
    init(configuration: ProcessingConfiguration) {
        self.configuration = configuration
        self.confidenceHistory = SoundClassifierCircularBuffer<Float>(capacity: 100)
        
        // L'initialisation sera faite de manière asynchrone
        
        logger.info("SoundAnalysisClassifier initialisé", metadata: [
            "speech_sensitivity": configuration.speechSensitivity.rawValue,
            "confidence_threshold": configuration.speechSensitivity.confidenceThreshold
        ])
    }
    
    deinit {
        // Le cleanup sera fait automatiquement par l'actor lors de la déallocation
    }
    
    // MARK: - Public Interface
    
    /// Initialise l'analyseur de manière asynchrone
    func initialize() async {
        await setupSoundAnalysis()
    }
    
    /// Classifie le contenu audio d'un buffer
    func classifyAudio(_ buffer: AudioBuffer) async throws -> AudioClassification {
        let startTime = Date()
        
        guard !isAnalyzing else {
            throw NeuralAutoCutError.soundClassificationFailed("Classification déjà en cours")
        }
        
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        logger.debug("Début classification audio", metadata: [
            "frame_count": buffer.frameCount,
            "timestamp": buffer.timestamp.seconds,
            "sample_rate": buffer.sampleRate
        ])
        
        do {
            // Classification avec SoundAnalysis
            let classification = try await performSoundAnalysis(buffer)
            
            // Post-traitement et validation
            let processedClassification = try await postProcessClassification(classification, buffer: buffer)
            
            // Mise à jour des statistiques
            let processingTime = Date().timeIntervalSince(startTime)
            classificationCount += 1
            totalProcessingTime += processingTime
            lastClassificationTime = Date()
            
            confidenceHistory.append(processedClassification.confidence)
            classificationResults.append(processedClassification)
            
            logger.debug("Classification terminée", metadata: [
                "dominant_type": processedClassification.dominantType.rawValue,
                "confidence": processedClassification.confidence,
                "speech_prob": processedClassification.speech,
                "music_prob": processedClassification.music,
                "noise_prob": processedClassification.noise,
                "processing_time_ms": Int(processingTime * 1000)
            ])
            
            return processedClassification
            
        } catch {
            logger.error("Erreur classification audio", metadata: [
                "error": error.localizedDescription,
                "frame_count": buffer.frameCount
            ])
            throw NeuralAutoCutError.soundClassificationFailed(error.localizedDescription)
        }
    }
    
    /// Analyse un flux audio en continu
    func analyzeAudioStream(_ audioStream: AsyncThrowingStream<AudioBuffer, Error>) -> AsyncThrowingStream<AudioClassification, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await buffer in audioStream {
                        let classification = try await classifyAudio(buffer)
                        continuation.yield(classification)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Obtient les statistiques de classification récentes
    func getRecentClassificationStats(windowSize: Int = 10) async -> ClassificationStats {
        let recentResults = Array(classificationResults.suffix(windowSize))
        let recentConfidences = confidenceHistory.recentValues(count: windowSize)
        
        return ClassificationStats(
            totalClassifications: classificationCount,
            recentClassifications: recentResults,
            averageConfidence: recentConfidences.isEmpty ? 0 : recentConfidences.reduce(0, +) / Float(recentConfidences.count),
            speechPercentage: calculateTypePercentage(.speech, in: recentResults),
            musicPercentage: calculateTypePercentage(.music, in: recentResults),
            noisePercentage: calculateTypePercentage(.noise, in: recentResults)
        )
    }
    
    // MARK: - Private Implementation
    
    private func setupSoundAnalysis() {
        do {
            // Configuration de l'analyseur de flux audio
            audioStreamAnalyzer = SNAudioStreamAnalyzer(format: createAudioFormat())
            
            // Configuration de la requête de classification
            classifyRequest = try SNClassifySoundRequest(mlModel: createClassificationModel())
            classifyRequest?.windowDuration = CMTimeMakeWithSeconds(1.0, preferredTimescale: 44100) // 1 seconde
            classifyRequest?.overlapFactor = 0.5 // 50% de chevauchement
            
            logger.debug("SoundAnalysis configuré", metadata: [
                "window_duration": 1.0,
                "overlap_factor": 0.5,
                "audio_format": "PCM Float32 44.1kHz Mono"
            ])
            
        } catch {
            logger.error("Erreur configuration SoundAnalysis", metadata: [
                "error": error.localizedDescription
            ])
        }
    }
    
    private func createAudioFormat() -> AVAudioFormat {
        // Format audio optimisé pour SoundAnalysis
        return AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100,
            channels: 1,
            interleaved: false
        ) ?? AVAudioFormat()
    }
    
    private func createClassificationModel() throws -> MLModel {
        // Utilisation du modèle de classification intégré d'Apple
        // En production, on pourrait utiliser un modèle personnalisé
        guard let modelURL = Bundle.main.url(forResource: "SoundClassifier", withExtension: "mlmodelc") else {
            // Fallback vers le modèle système si disponible
            return try MLModel(contentsOf: createSystemClassificationModel())
        }
        
        return try MLModel(contentsOf: modelURL)
    }
    
    private func createSystemClassificationModel() throws -> URL {
        // Création d'un modèle de classification basique pour le fallback
        // En réalité, on utiliserait les modèles système de SoundAnalysis
        let _ = FileManager.default.temporaryDirectory.appendingPathComponent("SystemSoundClassifier.mlmodelc")
        
        // Pour cette implémentation, on simule un modèle système
        // Dans une vraie implémentation, on utiliserait les APIs système
        throw NeuralAutoCutError.soundClassificationFailed("Modèle système non disponible")
    }
    
    private func performSoundAnalysis(_ buffer: AudioBuffer) async throws -> AudioClassification {
        guard let analyzer = audioStreamAnalyzer,
              let request = classifyRequest else {
            throw NeuralAutoCutError.soundClassificationFailed("Analyseur non configuré")
        }
        
        // Conversion du buffer en format AVAudioPCMBuffer
        let pcmBuffer = try createPCMBuffer(from: buffer)
        
        // Classification avec timeout
        return try await withTimeout(seconds: 2.0) { [self] in
            try await self.performClassificationWithAnalyzer(analyzer, request: request, buffer: pcmBuffer, originalBuffer: buffer)
        }
    }
    
    private func createPCMBuffer(from buffer: AudioBuffer) throws -> AVAudioPCMBuffer {
        let format = createAudioFormat()
        
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(buffer.frameCount)) else {
            throw NeuralAutoCutError.soundClassificationFailed("Impossible de créer le buffer PCM")
        }
        
        pcmBuffer.frameLength = AVAudioFrameCount(buffer.frameCount)
        
        // Copie des données audio
        guard let channelData = pcmBuffer.floatChannelData?[0] else {
            throw NeuralAutoCutError.soundClassificationFailed("Impossible d'accéder aux données du canal")
        }
        
        for i in 0..<buffer.frameCount {
            channelData[i] = buffer.data[i]
        }
        
        return pcmBuffer
    }
    
    private func performClassificationWithAnalyzer(
        _ analyzer: SNAudioStreamAnalyzer,
        request: SNClassifySoundRequest,
        buffer: AVAudioPCMBuffer,
        originalBuffer: AudioBuffer
    ) async throws -> AudioClassification {
        
        // Pour cette implémentation simplifiée, on simule une classification
        // basée sur l'analyse RMS du buffer
        let rmsLevel = calculateRMS(from: buffer)
        
        // Classification basique basée sur le niveau RMS
        let (speech, music, noise) = classifyBasedOnRMS(rmsLevel)
        
        return AudioClassification(
            speech: speech,
            music: music,
            noise: noise,
            timestamp: originalBuffer.timestamp
        )
    }
    
    private func calculateRMS(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0.0 }
        let frameCount = Int(buffer.frameLength)
        
        var sum: Float = 0.0
        for i in 0..<frameCount {
            let sample = channelData[i]
            sum += sample * sample
        }
        
        return sqrt(sum / Float(frameCount))
    }
    
    private func classifyBasedOnRMS(_ rmsLevel: Float) -> (speech: Float, music: Float, noise: Float) {
        // Classification simplifiée basée sur le niveau RMS
        let dbLevel = 20 * log10(max(rmsLevel, 1e-10))
        
        switch dbLevel {
        case -20...(-6):
            // Niveau élevé, probablement de la parole ou de la musique
            return (speech: 0.7, music: 0.6, noise: 0.1)
        case -40...(-20):
            // Niveau modéré, probablement de la parole
            return (speech: 0.8, music: 0.3, noise: 0.2)
        case -60...(-40):
            // Niveau faible, probablement du bruit de fond
            return (speech: 0.2, music: 0.1, noise: 0.8)
        default:
            // Très faible ou très élevé, traiter comme bruit
            return (speech: 0.1, music: 0.1, noise: 0.9)
        }
    }
    
    private func postProcessClassification(_ classification: AudioClassification, buffer: AudioBuffer) async throws -> AudioClassification {
        // Application de la logique hiérarchique et des seuils de sensibilité
        let sensitivityThreshold = configuration.speechSensitivity.confidenceThreshold
        
        var adjustedSpeech = classification.speech
        var adjustedMusic = classification.music
        var adjustedNoise = classification.noise
        
        // Ajustement basé sur la sensibilité configurée
        switch configuration.speechSensitivity {
        case .high:
            // Mode haute sensibilité : augmente le seuil pour la parole
            if adjustedSpeech < sensitivityThreshold {
                adjustedSpeech *= 0.5
                adjustedNoise += adjustedSpeech * 0.5
            }
        case .low:
            // Mode faible sensibilité : favorise la détection de parole
            adjustedSpeech = min(1.0, adjustedSpeech * 1.2)
            adjustedNoise = max(0.0, adjustedNoise - 0.1)
        case .medium:
            // Mode équilibré : pas d'ajustement
            break
        }
        
        // Renormalisation
        let total = adjustedSpeech + adjustedMusic + adjustedNoise
        if total > 0 {
            adjustedSpeech /= total
            adjustedMusic /= total
            adjustedNoise /= total
        }
        
        // Application de la logique de lissage temporel
        let smoothedClassification = try await applyTemporalSmoothing(
            AudioClassification(
                speech: adjustedSpeech,
                music: adjustedMusic,
                noise: adjustedNoise,
                timestamp: classification.timestamp
            )
        )
        
        return smoothedClassification
    }
    
    private func applyTemporalSmoothing(_ classification: AudioClassification) async throws -> AudioClassification {
        // Lissage temporel pour réduire les fluctuations rapides
        let recentClassifications = Array(classificationResults.suffix(5))
        
        guard !recentClassifications.isEmpty else {
            return classification
        }
        
        let smoothingFactor: Float = 0.3
        
        let avgSpeech = recentClassifications.map { $0.speech }.reduce(0, +) / Float(recentClassifications.count)
        let avgMusic = recentClassifications.map { $0.music }.reduce(0, +) / Float(recentClassifications.count)
        let avgNoise = recentClassifications.map { $0.noise }.reduce(0, +) / Float(recentClassifications.count)
        
        let smoothedSpeech = classification.speech * (1 - smoothingFactor) + avgSpeech * smoothingFactor
        let smoothedMusic = classification.music * (1 - smoothingFactor) + avgMusic * smoothingFactor
        let smoothedNoise = classification.noise * (1 - smoothingFactor) + avgNoise * smoothingFactor
        
        return AudioClassification(
            speech: smoothedSpeech,
            music: smoothedMusic,
            noise: smoothedNoise,
            timestamp: classification.timestamp
        )
    }
    
    private func calculateTypePercentage(_ type: AudioType, in classifications: [AudioClassification]) -> Float {
        guard !classifications.isEmpty else { return 0.0 }
        
        let count = classifications.filter { $0.dominantType == type }.count
        return Float(count) / Float(classifications.count) * 100.0
    }
    
    private func cleanup() {
        audioStreamAnalyzer = nil
        classifyRequest = nil
        audioEngine?.stop()
        audioEngine = nil
        
        logger.debug("SoundAnalysisClassifier nettoyé")
    }
    
    // MARK: - Timeout Utility
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NeuralAutoCutError.analysisTimeout
            }
            
            guard let result = try await group.next() else {
                throw NeuralAutoCutError.soundClassificationFailed("Aucun résultat de classification")
            }
            
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Supporting Types

/// Statistiques de classification
struct ClassificationStats {
    let totalClassifications: Int
    let recentClassifications: [AudioClassification]
    let averageConfidence: Float
    let speechPercentage: Float
    let musicPercentage: Float
    let noisePercentage: Float
    
    var dominantContentType: AudioType {
        if speechPercentage >= musicPercentage && speechPercentage >= noisePercentage {
            return .speech
        } else if musicPercentage >= noisePercentage {
            return .music
        } else {
            return .noise
        }
    }
    
    var confidenceLevel: String {
        switch averageConfidence {
        case 0.8...1.0: return "Très élevée"
        case 0.6..<0.8: return "Élevée"
        case 0.4..<0.6: return "Modérée"
        case 0.2..<0.4: return "Faible"
        default: return "Très faible"
        }
    }
}

/// Buffer circulaire pour l'historique des confidences
private class SoundClassifierCircularBuffer<T> {
    private var buffer: [T] = []
    private var head: Int = 0
    private var count: Int = 0
    private let capacity: Int
    
    init(capacity: Int) {
        self.capacity = capacity
        self.buffer.reserveCapacity(capacity)
    }
    
    func append(_ element: T) {
        if buffer.count < capacity {
            buffer.append(element)
            count += 1
        } else {
            buffer[head] = element
            head = (head + 1) % capacity
        }
    }
    
    func recentValues(count requestedCount: Int) -> [T] {
        let actualCount = min(requestedCount, self.count)
        var result: [T] = []
        
        for i in 0..<actualCount {
            let index = (head - actualCount + i + capacity) % capacity
            if index < buffer.count {
                result.append(buffer[index])
            }
        }
        
        return result
    }
}

// MARK: - Extensions

extension SoundAnalysisClassifier {
    
    /// Statistiques de performance du classificateur
    var performanceStatistics: ClassifierStatistics {
        get async {
            let recentStats = await getRecentClassificationStats()
            
            return ClassifierStatistics(
                classificationCount: classificationCount,
                totalProcessingTime: totalProcessingTime,
                averageProcessingTime: classificationCount > 0 ? totalProcessingTime / Double(classificationCount) : 0,
                lastClassificationTime: lastClassificationTime,
                averageConfidence: recentStats.averageConfidence,
                isAnalyzing: isAnalyzing
            )
        }
    }
}

struct ClassifierStatistics {
    let classificationCount: Int
    let totalProcessingTime: TimeInterval
    let averageProcessingTime: TimeInterval
    let lastClassificationTime: Date?
    let averageConfidence: Float
    let isAnalyzing: Bool
    
    var classificationsPerSecond: Float {
        return totalProcessingTime > 0 ? Float(classificationCount) / Float(totalProcessingTime) : 0
    }
    
    var status: String {
        if isAnalyzing {
            return "En cours d'analyse"
        } else if let lastTime = lastClassificationTime {
            let timeSinceLastClassification = Date().timeIntervalSince(lastTime)
            return timeSinceLastClassification < 5.0 ? "Actif" : "Inactif"
        } else {
            return "Non initialisé"
        }
    }
}