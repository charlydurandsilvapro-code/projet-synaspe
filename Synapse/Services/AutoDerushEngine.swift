import Foundation
import AVFoundation
import CoreMedia
import Accelerate

@available(macOS 14.0, *)
class AutoDerushEngine: ObservableObject {
    
    @Published var isProcessing: Bool = false
    @Published var progress: Float = 0.0
    @Published var currentTask: String = ""
    
    // Paramètres
    enum DerushSpeed: String, CaseIterable {
        case fast = "Rapide"
        case medium = "Moyen"
        case slow = "Lent"
        
        var releaseHold: TimeInterval {
            switch self {
            case .fast: return 0.15
            case .medium: return 0.4
            case .slow: return 0.8
            }
        }
        
        var description: String {
            switch self {
            case .fast: return "Coupe rapide (0.15s)"
            case .medium: return "Coupe modérée (0.4s)"
            case .slow: return "Coupe lente (0.8s)"
            }
        }
    }
    
    // Cette variable doit être dynamique maintenant !
    private var detectedSampleRate: Double = 44100
    
    func performAutoDerush(
        videoURL: URL,
        speed: DerushSpeed,
        silenceThreshold: Float,
        preserveMinDuration: TimeInterval = 0.5
    ) async throws -> DerushResult {
        
        isProcessing = true
        progress = 0.0
        defer { isProcessing = false; progress = 1.0 }
        
        // 1. Analyse Audio avec détection du Sample Rate
        currentTask = "Extraction et analyse du signal..."
        let audioAnalysis = try await analyzeVideoAudio(videoURL)
        
        // Mise à jour de la variable globale pour les calculs suivants
        self.detectedSampleRate = audioAnalysis.sampleRate
        progress = 0.3
        
        // 2. Détection Parole
        currentTask = "Détection intelligente..."
        let speechSegments = detectSmartSpeechSegments(
            audioAnalysis,
            threshold: silenceThreshold,
            releaseHold: speed.releaseHold
        )
        progress = 0.6
        
        // 3. Calcul des coupes
        currentTask = "Calcul de la timeline..."
        let cutPoints = generateCutPoints(speechSegments: speechSegments, minDuration: preserveMinDuration)
        progress = 0.8
        
        // 4. Création des segments finaux
        currentTask = "Finalisation..."
        let derushSegments = try await createDerushSegments(videoURL: videoURL, cutPoints: cutPoints)
        
        let originalDuration = audioAnalysis.duration
        let derushDuration = derushSegments.reduce(0) { $0 + $1.duration }
        
        return DerushResult(
            originalURL: videoURL,
            derushSegments: derushSegments,
            cutPoints: cutPoints,
            speechSegments: speechSegments,
            audioSamples: audioAnalysis.samples,
            originalDuration: originalDuration,
            derushDuration: derushDuration,
            compressionRatio: derushDuration / originalDuration,
            speed: speed,
            segmentsRemoved: cutPoints.count,
            silenceRemoved: originalDuration - derushDuration
        )
    }
    
    // MARK: - Analyse Audio Robuste
    private func analyzeVideoAudio(_ videoURL: URL) async throws -> AudioAnalysisData {
        let asset = AVAsset(url: videoURL)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw DerushError.noAudioTrack
        }
        
        // Lecture des vraies propriétés audio
        let desc = try await track.load(.formatDescriptions).first
        let rawSampleRate = desc?.audioStreamBasicDescription?.mSampleRate ?? 44100
        let rawChannelCount = desc?.audioStreamBasicDescription?.mChannelsPerFrame ?? 1
        let actualSampleRate = rawSampleRate > 0 ? rawSampleRate : 44100
        let channelCount = rawChannelCount > 0 ? rawChannelCount : 1
        
        let reader = try AVAssetReader(asset: asset)
        let settings: [String : Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: actualSampleRate, // Utiliser le vrai taux
            AVNumberOfChannelsKey: channelCount // Garder les canaux originaux pour le mix down
        ]
        
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        reader.add(output)
        guard reader.startReading() else {
            throw DerushError.audioReadFailed
        }
        
        var samples = [Float]()
        
        while let buffer = output.copyNextSampleBuffer() {
            guard let blockBuffer = CMSampleBufferGetDataBuffer(buffer) else { continue }
            let length = CMBlockBufferGetDataLength(blockBuffer)
            if length == 0 { continue }
            var dataPointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: nil, dataPointerOut: &dataPointer)
            guard let basePointer = dataPointer else { continue }
            
            let floatCount = length / 4
            if floatCount == 0 { continue }
            let floatPtr = basePointer.withMemoryRebound(to: Float.self, capacity: floatCount) { $0 }
            let bufferSamples = UnsafeBufferPointer(start: floatPtr, count: floatCount)
            
            // Downmix Stéréo -> Mono si nécessaire pour l'analyse
            if channelCount > 1 {
                for i in stride(from: 0, to: bufferSamples.count, by: Int(channelCount)) {
                    // Moyenne des canaux
                    var sum: Float = 0
                    for ch in 0..<Int(channelCount) {
                        if i + ch < bufferSamples.count {
                            sum += bufferSamples[i + ch]
                        }
                    }
                    samples.append(sum / Float(channelCount))
                }
            } else {
                samples.append(contentsOf: bufferSamples)
            }
        }
        
        let duration = actualSampleRate > 0 ? Double(samples.count) / actualSampleRate : 0
        return AudioAnalysisData(samples: samples, timeStamps: [], sampleRate: actualSampleRate, duration: duration)
    }
    
    // MARK: - Détection Intelligente
    private func detectSmartSpeechSegments(
        _ audioData: AudioAnalysisData,
        threshold: Float,
        releaseHold: TimeInterval
    ) -> [SpeechSegment] {
        
        var segments: [SpeechSegment] = []
        // Fenêtre d'analyse ~50ms
        let windowSize = Int(audioData.sampleRate * 0.05)
        
        var currentSegmentStart: TimeInterval?
        var lastSpeechTime: TimeInterval = 0
        var isSpeaking = false
        
        let samples = audioData.samples
        let count = samples.count
        guard audioData.sampleRate > 0, windowSize > 0, count > 0 else {
            return []
        }
        let zcrThreshold: Float = 0.4 // Plus permissif
        
        var i = 0
        while i < count - windowSize {
            let chunk = Array(samples[i..<(i+windowSize)])
            
            // 1. RMS (Volume)
            var rms: Float = 0
            vDSP_rmsqv(chunk, 1, &rms, vDSP_Length(windowSize))
            let db = 20 * log10(max(rms, 1e-10))
            
            // 2. ZCR (Fréquence)
            var zeroCrossings = 0
            for j in 1..<chunk.count {
                if (chunk[j] >= 0 && chunk[j-1] < 0) || (chunk[j] < 0 && chunk[j-1] >= 0) {
                    zeroCrossings += 1
                }
            }
            let zcr = Float(zeroCrossings) / Float(windowSize)
            
            // LOGIQUE DE DÉTECTION
            let isLoudEnough = db > threshold
            let isNotNoise = zcr < zcrThreshold
            
            let currentTime = Double(i) / audioData.sampleRate
            
            if isLoudEnough && isNotNoise {
                lastSpeechTime = currentTime
                if !isSpeaking {
                    isSpeaking = true
                    currentSegmentStart = currentTime
                }
            }
            
            // MAINTIEN (HOLD)
            if isSpeaking && (currentTime - lastSpeechTime > releaseHold) {
                if let start = currentSegmentStart {
                    // On garde un petit buffer de fin
                    segments.append(SpeechSegment(startTime: start, endTime: lastSpeechTime + 0.1, averageLevel: 0, confidence: 1))
                }
                isSpeaking = false
                currentSegmentStart = nil
            }
            
            i += windowSize
        }
        
        // Fin de fichier
        if isSpeaking, let start = currentSegmentStart {
            segments.append(SpeechSegment(startTime: start, endTime: Double(count)/audioData.sampleRate, averageLevel: 0, confidence: 1))
        }
        
        return segments
    }
    
    // MARK: - Génération des Coupes (Inchangé mais vital)
    private func generateCutPoints(speechSegments: [SpeechSegment], minDuration: TimeInterval) -> [DerushCutPoint] {
        var cuts: [DerushCutPoint] = []
        if speechSegments.isEmpty { return [] }
        
        for i in 0..<(speechSegments.count - 1) {
            let endOfCurrent = speechSegments[i].endTime
            let startOfNext = speechSegments[i+1].startTime
            
            if startOfNext - endOfCurrent > 0.1 { // Minimum 100ms de silence pour couper
                cuts.append(DerushCutPoint(
                    startTime: endOfCurrent,
                    endTime: startOfNext,
                    duration: startOfNext - endOfCurrent,
                    reason: "Silence",
                    silenceLevel: -60
                ))
            }
        }
        
        // Silence début
        if let first = speechSegments.first, first.startTime > 0.1 {
            cuts.insert(DerushCutPoint(startTime: 0, endTime: first.startTime, duration: first.startTime, reason: "Intro", silenceLevel: -60), at: 0)
        }
        
        return cuts
    }
    
    private func createDerushSegments(videoURL: URL, cutPoints: [DerushCutPoint]) async throws -> [DerushSegment] {
        let asset = AVAsset(url: videoURL)
        let totalDuration = try await asset.load(.duration).seconds
        var segments: [DerushSegment] = []
        var currentTime: TimeInterval = 0
        let sortedCuts = cutPoints.sorted { $0.startTime < $1.startTime }
        
        for cut in sortedCuts {
            if cut.startTime > currentTime {
                segments.append(DerushSegment(
                    id: UUID(),
                    originalStartTime: currentTime,
                    originalEndTime: cut.startTime,
                    duration: cut.startTime - currentTime,
                    timelinePosition: 0,
                    type: .kept,
                    sourceURL: videoURL
                ))
            }
            segments.append(DerushSegment(
                id: UUID(),
                originalStartTime: cut.startTime,
                originalEndTime: cut.endTime,
                duration: cut.duration,
                timelinePosition: 0,
                type: .removed,
                sourceURL: videoURL,
                removalReason: cut.reason
            ))
            currentTime = cut.endTime
        }
        
        if currentTime < totalDuration {
            segments.append(DerushSegment(
                id: UUID(),
                originalStartTime: currentTime,
                originalEndTime: totalDuration,
                duration: totalDuration - currentTime,
                timelinePosition: 0,
                type: .kept,
                sourceURL: videoURL
            ))
        }
        return segments
    }
    
    // --- Export Video ---
    func exportDerushVideo(_ result: DerushResult, outputURL: URL) async throws {
        let composition = AVMutableComposition()
        let asset = AVAsset(url: result.originalURL)
        
        guard let videoTrack = try? await asset.loadTracks(withMediaType: .video).first,
              let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first,
              let compVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw DerushError.exportFailed }
        
        let preferredTransform = try? await videoTrack.load(.preferredTransform)
        if let transform = preferredTransform {
            compVideo.preferredTransform = transform
        }
        
        var cursor = CMTime.zero
        for segment in result.derushSegments where segment.type == .kept {
            let range = CMTimeRange(
                start: CMTime(seconds: segment.originalStartTime, preferredTimescale: 600),
                duration: CMTime(seconds: segment.duration, preferredTimescale: 600)
            )
            try compVideo.insertTimeRange(range, of: videoTrack, at: cursor)
            try compAudio.insertTimeRange(range, of: audioTrack, at: cursor)
            cursor = CMTimeAdd(cursor, range.duration)
        }
        
        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else { return }
        export.outputURL = outputURL
        export.outputFileType = .mp4
        await export.export()
    }
    
    // --- Export FCPXML ---
    func exportToFCPXML(_ result: DerushResult, outputURL: URL) async throws {
        let xmlContent = generateFCPXML(segments: result.derushSegments.filter { $0.type == .kept }, originalURL: result.originalURL, projectName: "Synapse Auto-Cut")
        try xmlContent.write(to: outputURL, atomically: true, encoding: .utf8)
    }
    
    private func generateFCPXML(segments: [DerushSegment], originalURL: URL, projectName: String) -> String {
        // Format FCPXML 1.9 (plus compatible)
        let fps = 25 // Idéalement, détecter le FPS de la vidéo
        let frameDuration = "100/\(fps*100)s" // ex: 100/2500s
        
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE fcpxml>
        <fcpxml version="1.9">
            <resources>
                <format id="r1" name="FFVideoFormat1080p\(fps)" frameDuration="\(frameDuration)" width="1920" height="1080"/>
                <asset id="r2" name="\(originalURL.lastPathComponent)" uid="\(UUID().uuidString)" src="\(originalURL.absoluteString)" start="0s" duration="0s" hasVideo="1" hasAudio="1"/>
            </resources>
            <library>
                <event name="Synapse Event">
                    <project name="\(projectName)">
                        <sequence format="r1">
                            <spine>
        """
        
        var offset = 0.0
        for segment in segments {
            let start = String(format: "%.3f", segment.originalStartTime)
            let dur = String(format: "%.3f", segment.duration)
            let off = String(format: "%.3f", offset)
            
            xml += """
                                <asset-clip name="\(originalURL.lastPathComponent)" ref="r2" offset="\(off)s" start="\(start)s" duration="\(dur)s"/>
            """
            offset += segment.duration
        }
        
        xml += """
                            </spine>
                        </sequence>
                    </project>
                </event>
            </library>
        </fcpxml>
        """
        return xml
    }
    
    private func getVideoDuration(_ url: URL) async throws -> TimeInterval {
        return try await AVAsset(url: url).load(.duration).seconds
    }
}

// Supporting types
struct AudioAnalysisData {
    let samples: [Float]
    let timeStamps: [TimeInterval]
    let sampleRate: Double
    let duration: TimeInterval
}

struct SpeechSegment {
    let startTime: TimeInterval
    var endTime: TimeInterval
    let averageLevel: Float
    let confidence: Float
    
    var duration: TimeInterval {
        endTime - startTime
    }
}

struct DerushCutPoint {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let duration: TimeInterval
    let reason: String
    let silenceLevel: Float
}

struct DerushSegment: Equatable {
    let id: UUID
    let originalStartTime: TimeInterval
    let originalEndTime: TimeInterval
    let duration: TimeInterval
    let timelinePosition: TimeInterval
    let type: SegmentType
    let sourceURL: URL
    var removalReason: String?
    
    enum SegmentType: Equatable {
        case kept
        case removed
    }
}

struct DerushResult: Equatable {
    let originalURL: URL
    let derushSegments: [DerushSegment]
    let cutPoints: [DerushCutPoint]
    let speechSegments: [SpeechSegment]
    let audioSamples: [Float]
    let originalDuration: TimeInterval
    let derushDuration: TimeInterval
    let compressionRatio: TimeInterval
    let speed: AutoDerushEngine.DerushSpeed
    let segmentsRemoved: Int
    let silenceRemoved: TimeInterval
    
    static func == (lhs: DerushResult, rhs: DerushResult) -> Bool {
        lhs.originalURL == rhs.originalURL &&
        lhs.derushSegments.count == rhs.derushSegments.count &&
        lhs.originalDuration == rhs.originalDuration
    }
}

enum DerushError: Error {
    case noAudioTrack
    case audioReadFailed
    case exportFailed
}