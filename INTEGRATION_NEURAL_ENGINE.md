# Guide d'Intégration du NeuralAutoCutEngine

## Problème Actuel

L'application Synapse dispose de **deux architectures parallèles** qui ne communiquent pas entre elles :

### Architecture A - NeuralAutoCutEngine (Code Avancé)
- Localisation : `Synapse/Services/NeuralAutoCut/`
- Composants :
  - `NeuralAutoCutEngine` - Moteur principal
  - `AudioAnalysisPipeline` - Analyse audio FFT
  - `FFTProcessor` - Traitement spectral
  - `PCMStreamExtractor` - Extraction de flux audio
  - `VisionAnalysisEngine` - Analyse vidéo
  - `CompositionBuilder` - Construction AVFoundation

### Architecture B - ProjectViewModel (Interface Actuelle)
- Localisation : `Synapse/ViewModels/ProjectViewModel.swift`
- Utilise : `VideoSegment`, `AudioTrack`, `DetailedAudioAnalysis`
- Types de données incompatibles avec Architecture A

## Incompatibilités de Types

### 1. Configuration
**NeuralAutoCutEngine attend :**
```swift
public struct ProcessingConfiguration {
    public let silenceThreshold: Float
    public let minimumSilenceDuration: TimeInterval
    public let rhythmMode: RhythmMode
    // ... (20+ propriétés)
}
```

**ProjectViewModel essaie d'utiliser :**
```swift
var config = ProcessingConfiguration()
config.targetDuration = ...  // ❌ N'existe pas
config.enableBeatSync = ...  // ❌ N'existe pas
```

### 2. Résultats Audio
**AudioAnalysisPipeline retourne :**
```swift
[AnalyzedSegment] où AnalyzedSegment contient:
- segment: AudioSegment
- classification: AudioClassification
- qualityMetrics: QualityMetrics
// PAS de musicFeatures, energyLevel direct
```

**ProjectViewModel attend :**
```swift
DetailedAudioAnalysis(
    url: URL,
    bpm: Float,
    beatGrid: [CMTime],
    energyProfile: [EnergyPoint],
    spectralProfile: [SpectralFeatures],  // ❌ Type incompatible
    emotionalProfile: [EmotionalTone]     // ❌ Type incompatible
)
```

### 3. Timeline Segments
**NeuralAutoCutEngine retourne :**
```swift
public struct TimelineSegment {
    let originalStartTime: CMTime      // ❌ Pas startTime/endTime
    let originalEndTime: CMTime
    let timelineStartTime: CMTime
    let classification: AudioClassification
    // PAS de hasMotion, tags, saliencyCenter
}
```

**ProjectViewModel attend :**
```swift
struct VideoSegment {
    let sourceURL: URL
    var timeRange: CMTimeRange
    let qualityScore: Float
    let tags: [String]
    let saliencyCenter: CGPoint
}
```

## Solution Recommandée : Couche d'Adaptation

### Étape 1 : Créer un Adaptateur
Créer `Synapse/Services/NeuralAutoCutAdapter.swift` :

```swift
import AVFoundation

@available(macOS 14.0, *)
@MainActor
class NeuralAutoCutAdapter {
    private let neuralEngine: NeuralAutoCutEngine
    private let audioAnalysisPipeline: AudioAnalysisPipeline
    
    init() {
        self.neuralEngine = NeuralAutoCutEngine()
        self.audioAnalysisPipeline = AudioAnalysisPipeline()
    }
    
    // MARK: - Conversion Audio
    
    func analyzeAudio(url: URL) async throws -> DetailedAudioAnalysis {
        let asset = AVAsset(url: url)
        let audioSegments = try await audioAnalysisPipeline.analyzeAudio(asset)
        
        // Extraction des features musicales
        let bpm = extractBPM(from: audioSegments)
        let beatGrid = extractBeatGrid(from: audioSegments)
        let energyProfile = extractEnergyProfile(from: audioSegments)
        
        return DetailedAudioAnalysis(
            url: url,
            bpm: bpm,
            beatGrid: beatGrid,
            energyProfile: energyProfile,
            duration: asset.duration.seconds,
            confidence: 0.85
        )
    }
    
    private func extractBPM(from segments: [AnalyzedSegment]) -> Float {
        // TODO: Implémenter extraction BPM depuis AudioSegment
        // Probablement dans segment.classification ou segment.qualityMetrics
        return 120.0
    }
    
    private func extractBeatGrid(from segments: [AnalyzedSegment]) -> [CMTime] {
        // TODO: Analyser les segments pour détecter les beats
        return []
    }
    
    private func extractEnergyProfile(from segments: [AnalyzedSegment]) -> [EnergyPoint] {
        return segments.map { segment in
            // Convertir segment.qualityMetrics en EnergyPoint
            EnergyPoint(time: segment.segment.startTime.seconds, level: segment.qualityScore)
        }
    }
    
    // MARK: - Conversion Vidéo
    
    func processVideo(url: URL, configuration: SimplifiedConfig) async throws -> [VideoSegment] {
        let asset = AVAsset(url: url)
        
        // Construire ProcessingConfiguration réel
        let neuralConfig = ProcessingConfiguration(
            silenceThreshold: -50.0,
            minimumSilenceDuration: 0.5,
            rhythmMode: .moderate,
            enableVideoAnalysis: configuration.enableSceneDetection
        )
        
        let result = try await neuralEngine.processVideo(asset: asset, configuration: neuralConfig)
        
        // Convertir TimelineSegment → VideoSegment
        return result.timeline.map { neuralSeg in
            VideoSegment(
                sourceURL: url,
                timeRange: neuralSeg.originalTimeRange,
                qualityScore: neuralSeg.qualityScore,
                tags: convertClassification(neuralSeg.classification),
                saliencyCenter: .zero  // TODO: Extraire depuis metadata
            )
        }
    }
    
    private func convertClassification(_ classification: AudioClassification) -> [String] {
        // Convertir AudioClassification en tags lisibles
        switch classification {
        case .speech:
            return ["speech", "voice"]
        case .music:
            return ["music"]
        case .silence:
            return ["silence"]
        default:
            return ["unknown"]
        }
    }
}

// Configuration simplifiée pour l'interface
struct SimplifiedConfig {
    var targetDuration: TimeInterval?
    var enableBeatSync: Bool = true
    var enableSceneDetection: Bool = true
    var enableSpeechDetection: Bool = true
}
```

### Étape 2 : Modifier ProjectViewModel

```swift
@MainActor
class ProjectViewModel: ObservableObject {
    // Remplacer neuralEngine + audioAnalysisPipeline
    private let neuralAdapter = NeuralAutoCutAdapter()
    
    private func analyzeAudio(_ url: URL) async {
        isProcessing = true
        processingStatus = "Analyse audio en cours..."
        
        do {
            // Utiliser l'adaptateur
            let analysis = try await neuralAdapter.analyzeAudio(url: url)
            
            detailedAudioAnalysis = analysis
            project.musicTrack = AudioTrack(
                url: analysis.url,
                bpm: analysis.bpm,
                beatGrid: analysis.beatGrid,
                energyProfile: analysis.energyProfile
            )
            
            project.modifiedAt = Date()
        } catch {
            print("Failed to analyze audio: \(error)")
            processingStatus = "Erreur d'analyse audio: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
    
    func generateTimeline() async {
        // ...
        
        do {
            if !videoURLs.isEmpty {
                let config = SimplifiedConfig(
                    targetDuration: selectedPlatform.idealDuration,
                    enableBeatSync: true,
                    enableSceneDetection: true
                )
                
                let segments = try await neuralAdapter.processVideo(
                    url: videoURLs[0],
                    configuration: config
                )
                
                project.timeline = segments
                syncToTimelineEngine()
            }
        } catch {
            // ...
        }
    }
}
```

### Étape 3 : Implémenter les Conversions Manquantes

#### TODO dans NeuralAutoCutAdapter :

1. **extractBPM** : Analyser `AnalyzedSegment.qualityMetrics` ou utiliser FFTProcessor
2. **extractBeatGrid** : Utiliser les timestamps des beats dans AudioAnalysis
3. **extractEnergyProfile** : Mapper `qualityScore` → `EnergyPoint.level`
4. **convertClassification** : Mapping complet AudioClassification → tags
5. **extractSaliencyCenter** : Parser `TimelineSegment.metadata` pour obtenir la position

## Status Actuel du Code

### ✅ Corrections Appliquées
- Security Scoped Resources ajoutées (macOS sandboxing)
- Références aux mocks supprimées
- Imports de NeuralAutoCutEngine ajoutés
- Mode démo désactivé (fichiers inexistants)

### ❌ Bloquants Restants
- **35+ erreurs de compilation** dues aux incompatibilités de types
- Aucun adaptateur créé → appels directs impossibles
- Types ProcessingConfiguration / TimelineSegment incompatibles

### 🔄 Prochaines Étapes

1. **Créer `NeuralAutoCutAdapter.swift`** (priorité HAUTE)
2. **Implémenter conversions audio** (BPM, beatGrid, energy)
3. **Implémenter conversions vidéo** (TimelineSegment → VideoSegment)
4. **Remplacer appels directs** dans ProjectViewModel
5. **Tester compilation** + exécution
6. **Valider résultats** sur fichiers réels

## Estimation

- **Temps de développement :** 4-6 heures
- **Complexité :** Moyenne (types complexes mais logique claire)
- **Risques :** Perte de features avancées lors de la conversion

## Alternative : Refactoriser VideoSegment

Au lieu d'un adaptateur, **aligner VideoSegment sur TimelineSegment** :

```swift
struct VideoSegment: Identifiable {
    let id: UUID
    let sourceURL: URL
    var originalTimeRange: CMTimeRange  // Au lieu de timeRange
    var timelineTimeRange: CMTimeRange
    let qualityScore: Float
    let classification: AudioClassification  // Au lieu de tags
    let transitions: SegmentTransitions
    let metadata: SegmentMetadata
}
```

**Avantages** : Pas d'adaptateur, accès direct aux features Neural
**Inconvénients** : Refactorisation massive de toute l'app

## Recommandation Finale

**Utiliser l'Adaptateur** (Solution Étape 1-3) car :
- Moins invasif
- Conserve la compatibilité existante
- Permet une migration progressive
- Temps de développement raisonnable

Une fois l'adaptateur stable, envisager une refactorisation complète pour unifier les types.
