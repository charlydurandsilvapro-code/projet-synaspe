import Foundation
import AVFoundation
import Accelerate
import CoreMedia

@available(macOS 14.0, *)
class AudioAnalysisEngine: ObservableObject {
    
    // MARK: - Configuration
    private let windowSize: Int = 1024
    private let hopSize: Int = 512
    private let sampleRate: Double = 44100
    private let historySize: Int = 43 // 1 seconde d'historique (44100/1024)
    
    // MARK: - Beat Detection Parameters
    private let bassRange = (min: 60.0, max: 130.0)      // Kick drum range
    private let snareRange = (min: 301.0, max: 750.0)    // Snare drum range
    private let hihatRange = (min: 5000.0, max: 8000.0)  // Hi-hat range
    
    // MARK: - FFT Setup
    private var fftSetup: FFTSetup?
    private var window: [Float] = []
    private var fftBuffer: [Float] = []
    private var magnitudes: [Float] = []
    
    // MARK: - Beat Detection State
    private var energyHistory: [[Float]] = []
    private var beatThreshold: Float = 1.3
    private var lastBeatTime: TimeInterval = 0
    private var minBeatInterval: TimeInterval = 0.1 // Minimum 100ms between beats
    
    // MARK: - Analysis Results
    @Published var currentBPM: Float = 0
    @Published var beatConfidence: Float = 0
    @Published var energyLevels: EnergyLevels = EnergyLevels()
    @Published var isProcessing: Bool = false
    
    init() {
        setupFFT()
        setupWindow()
    }
    
    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }
    
    // MARK: - Setup Methods
    private func setupFFT() {
        let log2n = vDSP_Length(log2(Float(windowSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        
        fftBuffer = Array(repeating: 0.0, count: windowSize)
        magnitudes = Array(repeating: 0.0, count: windowSize / 2)
    }
    
    private func setupWindow() {
        // Fenêtre de Hanning pour réduire les artefacts spectraux
        window = Array(repeating: 0.0, count: windowSize)
        vDSP_hann_window(&window, vDSP_Length(windowSize), Int32(vDSP_HANN_NORM))
    }
    
    // MARK: - Main Analysis Method
    func analyzeAudio(from url: URL) async throws -> DetailedAudioAnalysis {
        isProcessing = true
        defer { isProcessing = false }
        
        let asset = AVAsset(url: url)
        let reader = try AVAssetReader(asset: asset)
        
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw AudioAnalysisError.noAudioTrack
        }
        
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1
        ]
        
        let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        reader.add(readerOutput)
        
        guard reader.startReading() else {
            throw AudioAnalysisError.readerFailed
        }
        
        var allSamples: [Float] = []
        var beatMarkers: [BeatMarker] = []
        var energySegments: [EnergySegment] = []
        var currentTime: TimeInterval = 0
        
        // Traitement par chunks
        while reader.status == .reading {
            guard let sampleBuffer = readerOutput.copyNextSampleBuffer() else { break }
            
            let samples = extractSamples(from: sampleBuffer)
            allSamples.append(contentsOf: samples)
            
            // Analyse par fenêtres glissantes
            let windowCount = (samples.count - windowSize) / hopSize + 1
            
            for windowIndex in 0..<windowCount {
                let startIndex = windowIndex * hopSize
                let endIndex = min(startIndex + windowSize, samples.count)
                
                if endIndex - startIndex == windowSize {
                    let windowSamples = Array(samples[startIndex..<endIndex])
                    
                    // Analyse FFT
                    let spectrum = performFFT(on: windowSamples)
                    
                    // Détection de beats
                    if let beat = detectBeat(spectrum: spectrum, time: currentTime) {
                        beatMarkers.append(beat)
                    }
                    
                    // Analyse énergétique
                    let energySegment = analyzeEnergy(spectrum: spectrum, time: currentTime)
                    energySegments.append(energySegment)
                    
                    currentTime += Double(hopSize) / sampleRate
                }
            }
            
            CMSampleBufferInvalidate(sampleBuffer)
        }
        
        // Calcul du BPM global
        let bpm = calculateBPM(from: beatMarkers)
        
        // Génération de la grille de beats raffinée
        let refinedBeatGrid = refineBeatGrid(beatMarkers, bpm: bpm)
        
        return DetailedAudioAnalysis(
            url: url,
            bpm: bpm,
            beatGrid: refinedBeatGrid,
            energyProfile: energySegments,
            duration: currentTime,
            confidence: beatConfidence
        )
    }
    
    // MARK: - FFT Analysis
    private func performFFT(on samples: [Float]) -> [Float] {
        guard let setup = fftSetup else { return [] }
        
        // Application de la fenêtre
        var windowedSamples = samples
        vDSP_vmul(windowedSamples, 1, window, 1, &windowedSamples, 1, vDSP_Length(windowSize))
        
        // Préparation pour FFT
        var realParts = Array(windowedSamples[0..<windowSize/2])
        var imagParts = Array(windowedSamples[windowSize/2..<windowSize])
        
        realParts.withUnsafeMutableBufferPointer { realPtr in
            imagParts.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                
                // FFT
                vDSP_fft_zip(setup, &splitComplex, 1, vDSP_Length(log2(Float(windowSize))), FFTDirection(FFT_FORWARD))
                
                // Calcul des magnitudes
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(windowSize/2))
            }
        }
        
        // Normalisation
        var normalizedMagnitudes = magnitudes
        var scale = Float(1.0 / Double(windowSize))
        vDSP_vsmul(normalizedMagnitudes, 1, &scale, &normalizedMagnitudes, 1, vDSP_Length(windowSize/2))
        
        return normalizedMagnitudes
    }
    
    // MARK: - Beat Detection
    private func detectBeat(spectrum: [Float], time: TimeInterval) -> BeatMarker? {
        // Calcul de l'énergie dans les bandes de fréquences critiques
        let bassEnergy = calculateBandEnergy(spectrum: spectrum, range: bassRange)
        let snareEnergy = calculateBandEnergy(spectrum: spectrum, range: snareRange)
        let hihatEnergy = calculateBandEnergy(spectrum: spectrum, range: hihatRange)
        
        let currentEnergy = [bassEnergy, snareEnergy, hihatEnergy]
        
        // Mise à jour de l'historique
        energyHistory.append(currentEnergy)
        if energyHistory.count > historySize {
            energyHistory.removeFirst()
        }
        
        // Détection de beat seulement si on a assez d'historique
        guard energyHistory.count >= historySize else { return nil }
        
        // Calcul des moyennes et variances
        let averages = calculateAverages()
        let variances = calculateVariances(averages: averages)
        
        // Seuils adaptatifs basés sur la variance
        let thresholds = variances.map { adaptiveThreshold(variance: $0) }
        
        // Détection de beat dans chaque bande
        var beatDetected = false
        var confidence: Float = 0
        var isDownbeat = false
        
        for (index, energy) in currentEnergy.enumerated() {
            let threshold = thresholds[index] * averages[index]
            if energy > threshold {
                beatDetected = true
                confidence = max(confidence, (energy - threshold) / threshold)
                
                // Les beats de basse sont souvent des downbeats
                if index == 0 && energy > bassEnergy * 1.5 {
                    isDownbeat = true
                }
            }
        }
        
        // Vérification de l'intervalle minimum entre beats
        if beatDetected && (time - lastBeatTime) >= minBeatInterval {
            lastBeatTime = time
            beatConfidence = confidence
            
            return BeatMarker(
                timestamp: time,
                confidence: confidence,
                isDownbeat: isDownbeat
            )
        }
        
        return nil
    }
    
    // MARK: - Energy Analysis
    private func analyzeEnergy(spectrum: [Float], time: TimeInterval) -> EnergySegment {
        let totalEnergy = spectrum.reduce(0, +)
        let bassEnergy = calculateBandEnergy(spectrum: spectrum, range: bassRange)
        let midEnergy = calculateBandEnergy(spectrum: spectrum, range: snareRange)
        let highEnergy = calculateBandEnergy(spectrum: spectrum, range: hihatRange)
        
        // Classification du niveau d'énergie
        let level: EnergyLevel
        if totalEnergy > 0.7 {
            level = .high
        } else if totalEnergy > 0.3 {
            level = .mid
        } else {
            level = .low
        }
        
        return EnergySegment(
            startTime: time,
            duration: Double(hopSize) / sampleRate,
            level: level,
            rmsAmplitude: sqrt(totalEnergy),
            bassEnergy: bassEnergy,
            midEnergy: midEnergy,
            highEnergy: highEnergy
        )
    }
    
    // MARK: - Helper Methods
    private func calculateBandEnergy(spectrum: [Float], range: (min: Double, max: Double)) -> Float {
        let binSize = sampleRate / Double(windowSize)
        let minBin = Int(range.min / binSize)
        let maxBin = min(Int(range.max / binSize), spectrum.count - 1)
        
        guard minBin < maxBin else { return 0 }
        
        let bandSpectrum = Array(spectrum[minBin...maxBin])
        return bandSpectrum.reduce(0, +) / Float(bandSpectrum.count)
    }
    
    private func calculateAverages() -> [Float] {
        let bandCount = energyHistory.first?.count ?? 0
        var averages = Array(repeating: Float(0), count: bandCount)
        
        for history in energyHistory {
            for (index, energy) in history.enumerated() {
                averages[index] += energy
            }
        }
        
        return averages.map { $0 / Float(energyHistory.count) }
    }
    
    private func calculateVariances(averages: [Float]) -> [Float] {
        let bandCount = averages.count
        var variances = Array(repeating: Float(0), count: bandCount)
        
        for history in energyHistory {
            for (index, energy) in history.enumerated() {
                let diff = energy - averages[index]
                variances[index] += diff * diff
            }
        }
        
        return variances.map { $0 / Float(energyHistory.count) }
    }
    
    private func adaptiveThreshold(variance: Float) -> Float {
        // Seuil adaptatif basé sur la variance (équation linéaire)
        return max(1.1, -15.0 * variance + 1.55)
    }
    
    private func calculateBPM(from beatMarkers: [BeatMarker]) -> Float {
        guard beatMarkers.count >= 2 else { return 0 }
        
        // Calcul des intervalles entre beats
        var intervals: [TimeInterval] = []
        for i in 1..<beatMarkers.count {
            let interval = beatMarkers[i].timestamp - beatMarkers[i-1].timestamp
            if interval > 0.2 && interval < 2.0 { // Filtrage des intervalles valides
                intervals.append(interval)
            }
        }
        
        guard !intervals.isEmpty else { return 0 }
        
        // Calcul de la médiane pour plus de robustesse
        intervals.sort()
        let medianInterval = intervals[intervals.count / 2]
        
        return Float(60.0 / medianInterval)
    }
    
    private func refineBeatGrid(_ beatMarkers: [BeatMarker], bpm: Float) -> [BeatMarker] {
        guard bpm > 0 && !beatMarkers.isEmpty else { return beatMarkers }
        
        let beatInterval = 60.0 / Double(bpm)
        var refinedGrid: [BeatMarker] = []
        
        // Utilisation du premier beat comme référence
        let firstBeat = beatMarkers.first!
        var currentTime = firstBeat.timestamp
        let endTime = beatMarkers.last!.timestamp + beatInterval
        
        while currentTime <= endTime {
            // Recherche du beat le plus proche dans la grille originale
            let closestBeat = beatMarkers.min { abs($0.timestamp - currentTime) < abs($1.timestamp - currentTime) }
            
            let confidence: Float
            let isDownbeat: Bool
            
            if let closest = closestBeat, abs(closest.timestamp - currentTime) < beatInterval * 0.3 {
                confidence = closest.confidence
                isDownbeat = closest.isDownbeat
            } else {
                confidence = 0.5 // Beat interpolé
                isDownbeat = false
            }
            
            refinedGrid.append(BeatMarker(
                timestamp: currentTime,
                confidence: confidence,
                isDownbeat: isDownbeat
            ))
            
            currentTime += beatInterval
        }
        
        return refinedGrid
    }
    
    private func extractSamples(from sampleBuffer: CMSampleBuffer) -> [Float] {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return [] }
        
        let length = CMBlockBufferGetDataLength(blockBuffer)
        let sampleCount = length / MemoryLayout<Float>.size
        
        var samples = Array<Float>(repeating: 0, count: sampleCount)
        
        CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: &samples)
        
        return samples
    }
}

// MARK: - Supporting Types
struct DetailedAudioAnalysis {
    let url: URL
    let bpm: Float
    let beatGrid: [BeatMarker]
    let energyProfile: [EnergySegment]
    let duration: TimeInterval
    let confidence: Float
}

struct EnergyLevels {
    var bass: Float = 0
    var mid: Float = 0
    var high: Float = 0
    var overall: Float = 0
}

// Extension pour EnergySegment avec plus de détails
extension EnergySegment {
    init(startTime: TimeInterval, duration: TimeInterval, level: EnergyLevel, rmsAmplitude: Float, bassEnergy: Float, midEnergy: Float, highEnergy: Float) {
        self.startTime = startTime
        self.duration = duration
        self.level = level
        self.rmsAmplitude = rmsAmplitude
    }
}

enum AudioAnalysisError: Error {
    case noAudioTrack
    case readerFailed
    case fftSetupFailed
    
    var localizedDescription: String {
        switch self {
        case .noAudioTrack:
            return "Aucune piste audio trouvée"
        case .readerFailed:
            return "Échec de la lecture audio"
        case .fftSetupFailed:
            return "Échec de l'initialisation FFT"
        }
    }
}