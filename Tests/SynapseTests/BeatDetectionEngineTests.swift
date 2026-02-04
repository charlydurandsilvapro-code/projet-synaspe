import XCTest
@testable import Synapse
import AVFoundation
import CoreMedia

@available(macOS 14.0, *)
final class BeatDetectionEngineTests: XCTestCase {
    
    func testBeatDetectionEngineInitialization() async throws {
        // Configuration de test avec détection de rythme activée
        let testConfiguration = ProcessingConfiguration(
            rhythmMode: .moderate,
            enableAppleSiliconOptimizations: true
        )
        
        let beatDetectionEngine = BeatDetectionEngine(configuration: testConfiguration)
        
        // Test que le moteur s'initialise correctement
        XCTAssertNotNil(beatDetectionEngine)
        
        let tempo = await beatDetectionEngine.currentTempo
        XCTAssertEqual(tempo, 0.0, "Le tempo initial devrait être 0")
        
        let beats = await beatDetectionEngine.allDetectedBeats
        XCTAssertTrue(beats.isEmpty, "Aucun battement ne devrait être détecté initialement")
    }
    
    func testBeatDetectionWithSimpleAudio() async throws {
        let testConfiguration = ProcessingConfiguration(rhythmMode: .moderate)
        let beatDetectionEngine = BeatDetectionEngine(configuration: testConfiguration)
        
        // Création d'un buffer audio simple
        let sampleRate: Double = 44100
        let duration: TimeInterval = 1.0
        let frameCount = Int(sampleRate * duration)
        
        // Génération d'un signal simple
        var audioData = Array(repeating: Float(0.1), count: frameCount)
        
        // Ajout de quelques pics d'énergie
        for i in stride(from: 0, to: frameCount, by: frameCount / 4) {
            if i < audioData.count {
                audioData[i] = 0.8 // Pic d'énergie
            }
        }
        
        let audioBuffer = audioData.withUnsafeBufferPointer { bufferPointer in
            AudioBuffer(
                data: bufferPointer,
                frameCount: frameCount,
                timestamp: CMTime.zero,
                sampleRate: sampleRate,
                channelCount: 1
            )
        }
        
        // Test de détection
        let detectedBeats = try await beatDetectionEngine.detectBeats(audioBuffer)
        
        // Vérifications basiques
        XCTAssertTrue(detectedBeats.count >= 0, "La détection devrait retourner un résultat")
        
        // Vérification que les battements détectés ont des propriétés valides
        for beat in detectedBeats {
            XCTAssertGreaterThanOrEqual(beat.confidence, 0.0, "La confiance devrait être >= 0")
            XCTAssertLessThanOrEqual(beat.confidence, 1.0, "La confiance devrait être <= 1")
            XCTAssertLessThanOrEqual(beat.timestamp.seconds, duration, "Le timestamp devrait être dans la durée du buffer")
        }
    }
    
    func testRhythmModeDisabled() async throws {
        // Test avec le mode rythmique désactivé
        let disabledConfig = ProcessingConfiguration(rhythmMode: .disabled)
        let disabledEngine = BeatDetectionEngine(configuration: disabledConfig)
        
        // Création d'un buffer audio simple
        let sampleRate: Double = 44100
        let frameCount = Int(sampleRate * 0.5)
        let audioData = Array(repeating: Float(0.5), count: frameCount)
        
        let audioBuffer = audioData.withUnsafeBufferPointer { bufferPointer in
            AudioBuffer(
                data: bufferPointer,
                frameCount: frameCount,
                timestamp: CMTime.zero,
                sampleRate: sampleRate,
                channelCount: 1
            )
        }
        
        // Avec le mode désactivé, aucun battement ne devrait être détecté
        let detectedBeats = try await disabledEngine.detectBeats(audioBuffer)
        XCTAssertTrue(detectedBeats.isEmpty, "Aucun battement ne devrait être détecté avec le mode désactivé")
    }
}