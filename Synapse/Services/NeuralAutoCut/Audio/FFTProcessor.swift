import Foundation
import Accelerate
import CoreMedia

// MARK: - FFT Processor

/// Processeur FFT optimisé pour l'analyse spectrale et la détection de rythme
@available(macOS 14.0, *)
actor FFTProcessor {
    
    // MARK: - Properties
    private let logger = NeuralLogger.forCategory("FFTProcessor")
    
    // MARK: - FFT Configuration
    private let fftSize: Int
    private let log2n: vDSP_Length
    private var fftSetup: FFTSetup?
    
    // MARK: - Working Buffers
    private var realBuffer: [Float]
    private var imagBuffer: [Float]
    private var complexBuffer: DSPSplitComplex
    private var magnitudeBuffer: [Float]
    private var window: [Float]
    
    // MARK: - Analysis Parameters
    private let sampleRate: Double
    private let hopSize: Int
    private let windowType: WindowType
    
    // MARK: - Performance Tracking
    private var fftCount: Int = 0
    private var totalProcessingTime: TimeInterval = 0
    
    // MARK: - Initialization
    
    init(
        fftSize: Int = 2048,
        sampleRate: Double = 44100.0,
        hopSize: Int = 1024,
        windowType: WindowType = .hann
    ) {
        self.fftSize = fftSize
        self.sampleRate = sampleRate
        self.hopSize = hopSize
        self.windowType = windowType
        self.log2n = vDSP_Length(log2(Float(fftSize)))
        
        // Initialisation des buffers
        self.realBuffer = Array(repeating: 0.0, count: fftSize)
        self.imagBuffer = Array(repeating: 0.0, count: fftSize)
        self.magnitudeBuffer = Array(repeating: 0.0, count: fftSize / 2)
        self.window = Array(repeating: 0.0, count: fftSize)
        
        // Configuration du buffer complexe
        self.complexBuffer = DSPSplitComplex(
            realp: UnsafeMutablePointer<Float>.allocate(capacity: fftSize / 2),
            imagp: UnsafeMutablePointer<Float>.allocate(capacity: fftSize / 2)
        )
        
        // Configuration FFT
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        
        // Génération de la fenêtre sera faite de manière asynchrone
        
        logger.info("FFTProcessor initialisé", metadata: [
            "fft_size": fftSize,
            "sample_rate": sampleRate,
            "hop_size": hopSize,
            "window_type": windowType.rawValue
        ])
    }
    
    deinit {
        // Libération des ressources
        complexBuffer.realp.deallocate()
        complexBuffer.imagp.deallocate()
        
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }
    
    // MARK: - Public Interface
    
    /// Initialise la fenêtre de manière asynchrone
    func initialize() async {
        await generateWindow()
    }
    
    /// Calcule la FFT d'un buffer audio et retourne le spectre de magnitude
    func computeFFT(_ audioData: [Float]) async throws -> FFTResult {
        let startTime = Date()
        
        guard audioData.count >= fftSize else {
            throw NeuralAutoCutError.beatDetectionFailed("Buffer audio trop petit pour FFT")
        }
        
        guard let setup = fftSetup else {
            throw NeuralAutoCutError.beatDetectionFailed("FFT setup non initialisé")
        }
        
        logger.debug("Début calcul FFT", metadata: [
            "input_size": audioData.count,
            "fft_size": fftSize
        ])
        
        do {
            // Préparation des données d'entrée
            try await prepareInputData(audioData)
            
            // Calcul FFT
            try await performFFT(setup: setup)
            
            // Calcul du spectre de magnitude
            let magnitudeSpectrum = try await computeMagnitudeSpectrum()
            
            // Génération des fréquences correspondantes
            let frequencies = generateFrequencyBins()
            
            // Calcul des caractéristiques spectrales
            let spectralFeatures = try await computeSpectralFeatures(magnitudeSpectrum)
            
            let processingTime = Date().timeIntervalSince(startTime)
            fftCount += 1
            totalProcessingTime += processingTime
            
            let result = FFTResult(
                magnitudeSpectrum: magnitudeSpectrum,
                frequencies: frequencies,
                spectralFeatures: spectralFeatures,
                fftSize: fftSize,
                sampleRate: sampleRate
            )
            
            logger.debug("FFT calculée", metadata: [
                "magnitude_bins": magnitudeSpectrum.count,
                "peak_frequency": spectralFeatures.peakFrequency,
                "spectral_centroid": spectralFeatures.spectralCentroid,
                "processing_time_ms": Int(processingTime * 1000)
            ])
            
            return result
            
        } catch {
            logger.error("Erreur calcul FFT", metadata: [
                "error": error.localizedDescription,
                "input_size": audioData.count
            ])
            throw error
        }
    }
    
    /// Analyse spectrale en continu d'un flux audio
    func analyzeSpectralStream(_ audioStream: AsyncThrowingStream<AudioBuffer, Error>) -> AsyncThrowingStream<FFTResult, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await buffer in audioStream {
                        // Conversion du buffer en array Float
                        let audioData = Array(buffer.data)
                        
                        // Traitement par fenêtres avec chevauchement
                        let numWindows = max(1, (audioData.count - fftSize) / hopSize + 1)
                        
                        for windowIndex in 0..<numWindows {
                            let startIndex = windowIndex * hopSize
                            let endIndex = min(startIndex + fftSize, audioData.count)
                            
                            if endIndex - startIndex >= fftSize {
                                let windowData = Array(audioData[startIndex..<endIndex])
                                let fftResult = try await computeFFT(windowData)
                                continuation.yield(fftResult)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Détecte les transitoires dans le spectre pour la détection de rythme
    func detectTransients(_ fftResult: FFTResult) async throws -> [TransientEvent] {
        let magnitudes = fftResult.magnitudeSpectrum
        var transients: [TransientEvent] = []
        
        // Analyse des bandes de fréquences pour différents types d'instruments
        let kickBand = try await analyzeBand(magnitudes, frequencies: fftResult.frequencies, lowFreq: 20, highFreq: 100)
        let snareBand = try await analyzeBand(magnitudes, frequencies: fftResult.frequencies, lowFreq: 150, highFreq: 300)
        let hihatBand = try await analyzeBand(magnitudes, frequencies: fftResult.frequencies, lowFreq: 8000, highFreq: 16000)
        
        // Détection de transitoires basée sur l'énergie des bandes
        if kickBand.energy > kickBand.threshold {
            transients.append(TransientEvent(
                type: .kick,
                frequency: kickBand.peakFrequency,
                magnitude: kickBand.energy,
                confidence: kickBand.confidence
            ))
        }
        
        if snareBand.energy > snareBand.threshold {
            transients.append(TransientEvent(
                type: .snare,
                frequency: snareBand.peakFrequency,
                magnitude: snareBand.energy,
                confidence: snareBand.confidence
            ))
        }
        
        if hihatBand.energy > hihatBand.threshold {
            transients.append(TransientEvent(
                type: .hihat,
                frequency: hihatBand.peakFrequency,
                magnitude: hihatBand.energy,
                confidence: hihatBand.confidence
            ))
        }
        
        return transients
    }
    
    /// Obtient les statistiques de traitement FFT
    var processingStatistics: FFTStatistics {
        get async {
            return FFTStatistics(
                fftCount: fftCount,
                totalProcessingTime: totalProcessingTime,
                averageProcessingTime: fftCount > 0 ? totalProcessingTime / Double(fftCount) : 0,
                fftSize: fftSize,
                sampleRate: sampleRate
            )
        }
    }
    
    // MARK: - Private Implementation
    
    private func generateWindow() {
        switch windowType {
        case .hann:
            vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        case .hamming:
            vDSP_hamm_window(&window, vDSP_Length(fftSize), 0)
        case .blackman:
            vDSP_blkman_window(&window, vDSP_Length(fftSize), 0)
        case .rectangular:
            window = Array(repeating: 1.0, count: fftSize)
        }
    }
    
    private func prepareInputData(_ audioData: [Float]) async throws {
        // Copie des données d'entrée
        for i in 0..<min(fftSize, audioData.count) {
            realBuffer[i] = audioData[i]
        }
        
        // Remplissage avec des zéros si nécessaire
        for i in audioData.count..<fftSize {
            realBuffer[i] = 0.0
        }
        
        // Application de la fenêtre
        vDSP_vmul(realBuffer, 1, window, 1, &realBuffer, 1, vDSP_Length(fftSize))
        
        // Préparation du buffer complexe
        for i in 0..<fftSize/2 {
            complexBuffer.realp[i] = realBuffer[2*i]
            complexBuffer.imagp[i] = realBuffer[2*i + 1]
        }
    }
    
    private func performFFT(setup: FFTSetup) async throws {
        // Calcul FFT forward
        vDSP_fft_zip(setup, &complexBuffer, 1, log2n, FFTDirection(FFT_FORWARD))
        
        // Normalisation
        var scale = Float(1.0) / Float(fftSize)
        vDSP_vsmul(complexBuffer.realp, 1, &scale, complexBuffer.realp, 1, vDSP_Length(fftSize/2))
        vDSP_vsmul(complexBuffer.imagp, 1, &scale, complexBuffer.imagp, 1, vDSP_Length(fftSize/2))
    }
    
    private func computeMagnitudeSpectrum() async throws -> [Float] {
        // Calcul du spectre de magnitude
        vDSP_zvmags(&complexBuffer, 1, &magnitudeBuffer, 1, vDSP_Length(fftSize/2))
        
        // Conversion en dB (optionnel)
        for i in 0..<magnitudeBuffer.count {
            magnitudeBuffer[i] = 20 * log10(max(magnitudeBuffer[i], 1e-10))
        }
        
        return magnitudeBuffer
    }
    
    private func generateFrequencyBins() -> [Float] {
        var frequencies: [Float] = []
        let binWidth = Float(sampleRate) / Float(fftSize)
        
        for i in 0..<fftSize/2 {
            frequencies.append(Float(i) * binWidth)
        }
        
        return frequencies
    }
    
    private func computeSpectralFeatures(_ magnitudeSpectrum: [Float]) async throws -> SpectralFeatures {
        // Recherche du pic de magnitude
        var peakIndex: vDSP_Length = 0
        var peakMagnitude: Float = 0
        vDSP_maxvi(magnitudeSpectrum, 1, &peakMagnitude, &peakIndex, vDSP_Length(magnitudeSpectrum.count))
        
        let peakFrequency = Float(peakIndex) * Float(sampleRate) / Float(fftSize)
        
        // Calcul du centroïde spectral
        let frequencies = generateFrequencyBins()
        var weightedSum: Float = 0
        var magnitudeSum: Float = 0
        
        for i in 0..<magnitudeSpectrum.count {
            let linearMagnitude = pow(10, magnitudeSpectrum[i] / 20) // Conversion dB vers linéaire
            weightedSum += frequencies[i] * linearMagnitude
            magnitudeSum += linearMagnitude
        }
        
        let spectralCentroid = magnitudeSum > 0 ? weightedSum / magnitudeSum : 0
        
        // Calcul de l'étalement spectral
        var varianceSum: Float = 0
        for i in 0..<magnitudeSpectrum.count {
            let linearMagnitude = pow(10, magnitudeSpectrum[i] / 20)
            let deviation = frequencies[i] - spectralCentroid
            varianceSum += deviation * deviation * linearMagnitude
        }
        
        let spectralSpread = magnitudeSum > 0 ? sqrt(varianceSum / magnitudeSum) : 0
        
        // Calcul de l'énergie spectrale
        var energy: Float = 0
        vDSP_sve(magnitudeSpectrum, 1, &energy, vDSP_Length(magnitudeSpectrum.count))
        
        return SpectralFeatures(
            peakFrequency: peakFrequency,
            peakMagnitude: peakMagnitude,
            spectralCentroid: spectralCentroid,
            spectralSpread: spectralSpread,
            spectralEnergy: energy
        )
    }
    
    private func analyzeBand(_ magnitudes: [Float], frequencies: [Float], lowFreq: Float, highFreq: Float) async throws -> BandAnalysis {
        var bandEnergy: Float = 0
        var peakMagnitude: Float = -Float.infinity
        var peakFrequency: Float = 0
        var binCount = 0
        
        for i in 0..<magnitudes.count {
            let freq = frequencies[i]
            if freq >= lowFreq && freq <= highFreq {
                let linearMagnitude = pow(10, magnitudes[i] / 20)
                bandEnergy += linearMagnitude
                
                if magnitudes[i] > peakMagnitude {
                    peakMagnitude = magnitudes[i]
                    peakFrequency = freq
                }
                
                binCount += 1
            }
        }
        
        // Calcul du seuil adaptatif (simple)
        let threshold = bandEnergy * 0.7 // 70% de l'énergie moyenne
        
        // Calcul de la confiance
        let confidence = binCount > 0 ? min(1.0, bandEnergy / (Float(binCount) * 0.1)) : 0.0
        
        return BandAnalysis(
            energy: bandEnergy,
            peakFrequency: peakFrequency,
            peakMagnitude: peakMagnitude,
            threshold: threshold,
            confidence: confidence
        )
    }
}

// MARK: - Supporting Types

/// Types de fenêtres pour l'analyse FFT
public enum WindowType: String, CaseIterable {
    case hann = "Hann"
    case hamming = "Hamming"
    case blackman = "Blackman"
    case rectangular = "Rectangulaire"
}

/// Résultat d'analyse FFT
public struct FFTResult {
    public let magnitudeSpectrum: [Float]
    public let frequencies: [Float]
    public let spectralFeatures: SpectralFeatures
    public let fftSize: Int
    public let sampleRate: Double
    
    public init(magnitudeSpectrum: [Float], frequencies: [Float], spectralFeatures: SpectralFeatures, fftSize: Int, sampleRate: Double) {
        self.magnitudeSpectrum = magnitudeSpectrum
        self.frequencies = frequencies
        self.spectralFeatures = spectralFeatures
        self.fftSize = fftSize
        self.sampleRate = sampleRate
    }
}

/// Caractéristiques spectrales
public struct SpectralFeatures {
    public let peakFrequency: Float
    public let peakMagnitude: Float
    public let spectralCentroid: Float
    public let spectralSpread: Float
    public let spectralEnergy: Float
    
    public init(peakFrequency: Float, peakMagnitude: Float, spectralCentroid: Float, spectralSpread: Float, spectralEnergy: Float) {
        self.peakFrequency = peakFrequency
        self.peakMagnitude = peakMagnitude
        self.spectralCentroid = spectralCentroid
        self.spectralSpread = spectralSpread
        self.spectralEnergy = spectralEnergy
    }
}

/// Événement transitoire détecté
public struct TransientEvent {
    public let type: TransientType
    public let frequency: Float
    public let magnitude: Float
    public let confidence: Float
    
    public init(type: TransientType, frequency: Float, magnitude: Float, confidence: Float) {
        self.type = type
        self.frequency = frequency
        self.magnitude = magnitude
        self.confidence = confidence
    }
}

/// Types de transitoires
public enum TransientType: String, CaseIterable {
    case kick = "Kick"
    case snare = "Snare"
    case hihat = "Hi-hat"
    case cymbal = "Cymbale"
    case other = "Autre"
}

/// Analyse de bande de fréquences
private struct BandAnalysis {
    let energy: Float
    let peakFrequency: Float
    let peakMagnitude: Float
    let threshold: Float
    let confidence: Float
}

/// Statistiques de traitement FFT
public struct FFTStatistics {
    public let fftCount: Int
    public let totalProcessingTime: TimeInterval
    public let averageProcessingTime: TimeInterval
    public let fftSize: Int
    public let sampleRate: Double
    
    public var fftsPerSecond: Float {
        return totalProcessingTime > 0 ? Float(fftCount) / Float(totalProcessingTime) : 0
    }
    
    public var efficiency: String {
        let fps = fftsPerSecond
        switch fps {
        case 100...: return "Très rapide"
        case 50..<100: return "Rapide"
        case 10..<50: return "Modéré"
        default: return "Lent"
        }
    }
}