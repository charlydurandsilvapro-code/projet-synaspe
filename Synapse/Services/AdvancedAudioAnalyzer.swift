import Foundation
import Accelerate

/// Analyseur audio avancé avec détection spectrale et vocal frequencies
@available(macOS 14.0, *)
class AdvancedAudioAnalyzer {
    
    // MARK: - Spectral Analysis
    /// Détecte si la fenêtre contient de la parole via analyse spectrale
    static func isVoiceActivityDetected(
        _ samples: [Float],
        sampleRate: Double
    ) -> Bool {
        guard samples.count >= 256 else { return false }
        
        // 1. FFT pour analyse spectrale
        let fftLength = 512
        let paddedSamples = Array(samples.prefix(fftLength))
        
        // 2. Fenêtrage Hamming
        let window = hammingWindow(length: paddedSamples.count)
        let windowedSamples = zip(paddedSamples, window).map { $0 * $1 }
        
        // 3. Calcul du spectre
        let spectrum = computeSpectrum(windowedSamples, fftLength: fftLength)
        
        // 4. Analyse des bandes de fréquences vocales (300-3000 Hz)
        let vocalPower = analyzeVocalBands(spectrum, sampleRate: sampleRate)
        let noisePower = analyzeNoiseBands(spectrum, sampleRate: sampleRate)
        
        // 5. Détection si ratio vocal/bruit > 2.0
        return vocalPower / max(noisePower, 1e-10) > 2.0
    }
    
    /// Fenêtrage Hamming pour FFT
    private static func hammingWindow(length: Int) -> [Float] {
        var window = [Float](repeating: 0, count: length)
        for i in 0..<length {
            let normalized = Float(i) / Float(length - 1)
            window[i] = 0.54 - 0.46 * cos(2.0 * .pi * normalized)
        }
        return window
    }
    
    /// Calcul du spectre via FFT simple
    private static func computeSpectrum(_ samples: [Float], fftLength: Int) -> [Float] {
        // Simple approximation du spectre par energie RMS par bandes
        var spectrum = [Float](repeating: 0, count: fftLength / 2)
        let bandSize = max(1, samples.count / spectrum.count)
        
        for band in 0..<spectrum.count {
            let start = band * bandSize
            let end = min(start + bandSize, samples.count)
            let bandSamples = Array(samples[start..<end])
            spectrum[band] = sqrt(bandSamples.reduce(0) { $0 + $1 * $1 } / Float(bandSamples.count))
        }
        
        return spectrum
    }
    
    /// Analyse les bandes vocales (300-3000 Hz)
    private static func analyzeVocalBands(_ spectrum: [Float], sampleRate: Double) -> Float {
        guard !spectrum.isEmpty else { return 0 }
        
        let nyquist = sampleRate / 2
        let freqPerBin = nyquist / Double(spectrum.count)
        
        let minFreq = 300.0
        let maxFreq = 3000.0
        let minBin = Int(minFreq / freqPerBin)
        let maxBin = Int(maxFreq / freqPerBin)
        
        let vocalRange = spectrum[max(0, minBin)..<min(spectrum.count, maxBin)]
        return vocalRange.reduce(0, +) / Float(vocalRange.count)
    }
    
    /// Analyse les bandes de bruit (<300Hz, >3000Hz)
    private static func analyzeNoiseBands(_ spectrum: [Float], sampleRate: Double) -> Float {
        guard !spectrum.isEmpty else { return 0 }
        
        let nyquist = sampleRate / 2
        let freqPerBin = nyquist / Double(spectrum.count)
        
        let lowBand = spectrum[0..<Int(300.0 / freqPerBin)].reduce(0, +)
        let highBand = spectrum[Int(3000.0 / freqPerBin)..<spectrum.count].reduce(0, +)
        
        let totalBins = Int(300.0 / freqPerBin) + (spectrum.count - Int(3000.0 / freqPerBin))
        return (lowBand + highBand) / Float(max(1, totalBins))
    }
    
    /// Détecte les transitoires (attaques de consonnes)
    static func detectTransients(_ samples: [Float]) -> Bool {
        guard samples.count >= 2 else { return false }
        
        var maxDelta: Float = 0
        for i in 1..<samples.count {
            let delta = abs(samples[i] - samples[i-1])
            maxDelta = max(maxDelta, delta)
        }
        
        // Transitoire significatif si delta > 0.3
        return maxDelta > 0.3
    }
    
    /// Analyse la clarté du signal (vs bruit statique)
    static func analyzeSignalClarity(_ samples: [Float]) -> Float {
        guard samples.count > 1 else { return 0 }
        
        let mean = samples.reduce(0, +) / Float(samples.count)
        let variance = samples.reduce(0) { $0 + pow($1 - mean, 2) } / Float(samples.count)
        let stdDev = sqrt(variance)
        
        // Ratio puissance / bruit statique
        let rms = sqrt(samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count))
        return stdDev > 0 ? rms / stdDev : 0
    }
}
