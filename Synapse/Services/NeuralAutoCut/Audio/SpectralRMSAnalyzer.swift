import Foundation
import AVFoundation
import Accelerate
import CoreMedia

// MARK: - Spectral RMS Analyzer

/// Analyseur RMS spectral utilisant le framework Accelerate pour des performances optimales
@available(macOS 14.0, *)
actor SpectralRMSAnalyzer {
    
    // MARK: - Properties
    private let logger = NeuralLogger.rmsAnalyzer
    private let configuration: ProcessingConfiguration
    
    // MARK: - vDSP Components
    private var fftSetup: FFTSetup?
    private let windowSize: Int
    private let hopSize: Int
    private var window: [Float]
    
    // MARK: - Analysis State
    private var rmsHistory: CircularBuffer<Float>
    private var silenceThreshold: Float
    private var adaptiveThreshold: Float
    
    // MARK: - Performance Tracking
    private var analysisCount: Int = 0
    private var totalProcessingTime: TimeInterval = 0
    
    // MARK: - Initialization
    
    init(configuration: ProcessingConfiguration) {
        self.configuration = configuration
        self.windowSize = 2048
        self.hopSize = 1024
        self.silenceThreshold = configuration.silenceThreshold
        self.adaptiveThreshold = configuration.silenceThreshold
        self.rmsHistory = CircularBuffer<Float>(capacity: 100)
        
        // Création de la fenêtre de Hann pour l'analyse spectrale
        self.window = Array(repeating: 0.0, count: windowSize)
        vDSP_hann_window(&window, vDSP_Length(windowSize), Int32(vDSP_HANN_NORM))
        
        // Configuration FFT
        let log2n = vDSP_Length(log2(Float(windowSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        
        logger.info("SpectralRMSAnalyzer initialisé", metadata: [
            "window_size": windowSize,
            "hop_size": hopSize,
            "silence_threshold": silenceThreshold,
            "enable_optimizations": configuration.enableAppleSiliconOptimizations
        ])
    }
    
    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }
    
    // MARK: - Public Interface
    
    /// Analyse RMS d'un buffer audio avec détection de silence
    func analyzeRMS(_ buffer: AudioBuffer) async throws -> RMSAnalysisResult {
        let startTime = Date()
        
        logger.debug("Début analyse RMS", metadata: [
            "frame_count": buffer.frameCount,
            "timestamp": buffer.timestamp.seconds,
            "sample_rate": buffer.sampleRate
        ])
        
        do {
            // Calcul RMS par fenêtres
            let rmsValues = try await calculateRMSWindows(buffer)
            
            // Génération des timestamps correspondants
            let timestamps = generateTimestamps(for: rmsValues, buffer: buffer)
            
            // Détection des segments de silence
            let silenceSegments = try await detectSilenceSegments(rmsValues: rmsValues, timestamps: timestamps)
            
            // Mise à jour de l'historique et du seuil adaptatif
            updateAdaptiveThreshold(rmsValues)
            
            // Création du résultat
            let result = RMSAnalysisResult(
                rmsValues: rmsValues,
                timestamps: timestamps,
                silenceSegments: silenceSegments
            )
            
            // Mise à jour des statistiques
            let processingTime = Date().timeIntervalSince(startTime)
            analysisCount += 1
            totalProcessingTime += processingTime
            
            logger.debug("Analyse RMS terminée", metadata: [
                "rms_windows": rmsValues.count,
                "silence_segments": silenceSegments.count,
                "average_rms": result.averageRMS,
                "peak_rms": result.peakRMS,
                "processing_time_ms": Int(processingTime * 1000)
            ])
            
            return result
            
        } catch {
            logger.error("Erreur analyse RMS", metadata: [
                "error": error.localizedDescription,
                "frame_count": buffer.frameCount
            ])
            throw NeuralAutoCutError.rmsAnalysisFailed(error.localizedDescription)
        }
    }
    
    /// Analyse RMS en continu d'un flux audio
    func analyzeRMSStream(_ audioStream: AsyncThrowingStream<AudioBuffer, Error>) -> AsyncThrowingStream<RMSAnalysisResult, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await buffer in audioStream {
                        let result = try await analyzeRMS(buffer)
                        continuation.yield(result)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Obtient les statistiques d'analyse actuelles
    var analysisStatistics: RMSAnalysisStatistics {
        get async {
            return RMSAnalysisStatistics(
                analysisCount: analysisCount,
                totalProcessingTime: totalProcessingTime,
                averageProcessingTime: analysisCount > 0 ? totalProcessingTime / Double(analysisCount) : 0,
                currentSilenceThreshold: silenceThreshold,
                adaptiveThreshold: adaptiveThreshold,
                recentRMSValues: rmsHistory.recentValues(count: 10)
            )
        }
    }
    
    // MARK: - Private Implementation
    
    private func calculateRMSWindows(_ buffer: AudioBuffer) async throws -> [Float] {
        guard buffer.frameCount > 0 else {
            throw NeuralAutoCutError.rmsAnalysisFailed("Buffer audio vide")
        }
        
        var rmsValues: [Float] = []
        let numWindows = max(1, (buffer.frameCount - windowSize) / hopSize + 1)
        
        // Buffers de travail pour vDSP
        var windowedSignal = [Float](repeating: 0.0, count: windowSize)
        
        for windowIndex in 0..<numWindows {
            let startIndex = windowIndex * hopSize
            let endIndex = min(startIndex + windowSize, buffer.frameCount)
            let actualWindowSize = endIndex - startIndex
            
            guard actualWindowSize > 0 else { continue }
            
            // Extraction de la fenêtre
            for i in 0..<actualWindowSize {
                let bufferIndex = startIndex + i
                if bufferIndex < buffer.data.count {
                    windowedSignal[i] = buffer.data[bufferIndex]
                } else {
                    windowedSignal[i] = 0.0
                }
            }
            
            // Remplissage avec des zéros si nécessaire
            for i in actualWindowSize..<windowSize {
                windowedSignal[i] = 0.0
            }
            
            // Application de la fenêtre de Hann
            vDSP_vmul(windowedSignal, 1, window, 1, &windowedSignal, 1, vDSP_Length(windowSize))
            
            // Calcul RMS optimisé avec vDSP
            let rms = try await calculateWindowRMS(windowedSignal, windowSize: actualWindowSize)
            rmsValues.append(rms)
        }
        
        return rmsValues
    }
    
    private func calculateWindowRMS(_ windowedSignal: [Float], windowSize: Int) async throws -> Float {
        guard windowSize > 0 else { return 0.0 }
        
        var squaredSignal = [Float](repeating: 0.0, count: windowSize)
        var sumOfSquares: Float = 0.0
        
        // Calcul vectorisé du carré des échantillons
        vDSP_vsq(windowedSignal, 1, &squaredSignal, 1, vDSP_Length(windowSize))
        
        // Somme vectorisée
        vDSP_sve(squaredSignal, 1, &sumOfSquares, vDSP_Length(windowSize))
        
        // Calcul RMS final
        let meanSquare = sumOfSquares / Float(windowSize)
        let rms = sqrt(meanSquare)
        
        return rms
    }
    
    private func generateTimestamps(for rmsValues: [Float], buffer: AudioBuffer) -> [CMTime] {
        var timestamps: [CMTime] = []
        
        for (index, _) in rmsValues.enumerated() {
            let sampleOffset = Double(index * hopSize) / buffer.sampleRate
            let timestamp = CMTimeAdd(
                buffer.timestamp,
                CMTime(seconds: sampleOffset, preferredTimescale: 600)
            )
            timestamps.append(timestamp)
        }
        
        return timestamps
    }
    
    private func detectSilenceSegments(rmsValues: [Float], timestamps: [CMTime]) async throws -> [SilenceSegment] {
        var silenceSegments: [SilenceSegment] = []
        var currentSilenceStart: CMTime?
        var currentSilenceRMS: [Float] = []
        
        for (index, rms) in rmsValues.enumerated() {
            let timestamp = timestamps[index]
            let dbLevel = 20 * log10(max(rms, 1e-10))
            let isSilent = dbLevel < adaptiveThreshold
            
            if isSilent {
                // Début ou continuation du silence
                if currentSilenceStart == nil {
                    currentSilenceStart = timestamp
                    currentSilenceRMS = []
                }
                currentSilenceRMS.append(rms)
                
            } else {
                // Fin du silence
                if let silenceStart = currentSilenceStart {
                    let silenceDuration = timestamp.seconds - silenceStart.seconds
                    
                    // Vérification de la durée minimale
                    if silenceDuration >= configuration.minimumSilenceDuration {
                        let averageRMS = currentSilenceRMS.isEmpty ? 0 : 
                            currentSilenceRMS.reduce(0, +) / Float(currentSilenceRMS.count)
                        let confidence = calculateSilenceConfidence(averageRMS)
                        
                        let silenceSegment = SilenceSegment(
                            startTime: silenceStart,
                            endTime: timestamp,
                            averageLevel: 20 * log10(max(averageRMS, 1e-10)),
                            confidence: confidence
                        )
                        
                        silenceSegments.append(silenceSegment)
                    }
                    
                    currentSilenceStart = nil
                    currentSilenceRMS = []
                }
            }
        }
        
        // Traitement du silence final si nécessaire
        if let silenceStart = currentSilenceStart,
           let lastTimestamp = timestamps.last {
            let silenceDuration = lastTimestamp.seconds - silenceStart.seconds
            
            if silenceDuration >= configuration.minimumSilenceDuration {
                let averageRMS = currentSilenceRMS.isEmpty ? 0 : 
                    currentSilenceRMS.reduce(0, +) / Float(currentSilenceRMS.count)
                let confidence = calculateSilenceConfidence(averageRMS)
                
                let silenceSegment = SilenceSegment(
                    startTime: silenceStart,
                    endTime: lastTimestamp,
                    averageLevel: 20 * log10(max(averageRMS, 1e-10)),
                    confidence: confidence
                )
                
                silenceSegments.append(silenceSegment)
            }
        }
        
        return silenceSegments
    }
    
    private func calculateSilenceConfidence(_ averageRMS: Float) -> Float {
        let dbLevel = 20 * log10(max(averageRMS, 1e-10))
        let thresholdDifference = adaptiveThreshold - dbLevel
        
        // Confiance basée sur la différence avec le seuil
        let confidence = min(1.0, max(0.0, thresholdDifference / 20.0))
        return confidence
    }
    
    private func updateAdaptiveThreshold(_ rmsValues: [Float]) {
        // Ajout des nouvelles valeurs à l'historique
        for rms in rmsValues {
            rmsHistory.append(rms)
        }
        
        // Calcul du seuil adaptatif basé sur l'historique récent
        let recentValues = rmsHistory.recentValues(count: 50)
        guard !recentValues.isEmpty else { return }
        
        // Calcul de la médiane pour robustesse aux outliers
        let sortedValues = recentValues.sorted()
        let median = sortedValues[sortedValues.count / 2]
        let medianDB = 20 * log10(max(median, 1e-10))
        
        // Ajustement du seuil adaptatif
        let baseThreshold = configuration.silenceThreshold
        let adaptiveAdjustment = configuration.silenceDetectionSensitivity.thresholdAdjustment
        
        // Combinaison du seuil de base, de l'ajustement de sensibilité et de l'adaptation
        adaptiveThreshold = min(baseThreshold + adaptiveAdjustment, medianDB - 10.0)
        
        logger.debug("Seuil adaptatif mis à jour", metadata: [
            "base_threshold": baseThreshold,
            "adaptive_threshold": adaptiveThreshold,
            "median_db": medianDB,
            "recent_samples": recentValues.count
        ])
    }
}

// MARK: - Supporting Types

/// Buffer circulaire pour l'historique RMS
private class CircularBuffer<T> {
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

/// Statistiques d'analyse RMS
public struct RMSAnalysisStatistics {
    public let analysisCount: Int
    public let totalProcessingTime: TimeInterval
    public let averageProcessingTime: TimeInterval
    public let currentSilenceThreshold: Float
    public let adaptiveThreshold: Float
    public let recentRMSValues: [Float]
    
    public var analysisPerSecond: Float {
        return totalProcessingTime > 0 ? Float(analysisCount) / Float(totalProcessingTime) : 0
    }
    
    public var efficiency: String {
        let aps = analysisPerSecond
        switch aps {
        case 100...: return "Très efficace"
        case 50..<100: return "Efficace"
        case 10..<50: return "Modéré"
        default: return "Lent"
        }
    }
    
    public var thresholdStatus: String {
        let difference = abs(currentSilenceThreshold - adaptiveThreshold)
        switch difference {
        case 0..<2: return "Stable"
        case 2..<5: return "Adaptation modérée"
        default: return "Adaptation forte"
        }
    }
}

// MARK: - Extensions

extension SpectralRMSAnalyzer {
    
    /// Analyse RMS rapide pour les tests
    func quickRMSAnalysis(_ buffer: AudioBuffer) async throws -> Float {
        guard buffer.frameCount > 0 else { return 0.0 }
        
        var sumOfSquares: Float = 0.0
        
        // Calcul RMS simple sans fenêtrage
        vDSP_svesq(buffer.data.baseAddress!, 1, &sumOfSquares, vDSP_Length(buffer.frameCount))
        
        let meanSquare = sumOfSquares / Float(buffer.frameCount)
        return sqrt(meanSquare)
    }
    
    /// Détection de silence simple
    func isBufferSilent(_ buffer: AudioBuffer) async throws -> Bool {
        let rms = try await quickRMSAnalysis(buffer)
        let dbLevel = 20 * log10(max(rms, 1e-10))
        return dbLevel < adaptiveThreshold
    }
}