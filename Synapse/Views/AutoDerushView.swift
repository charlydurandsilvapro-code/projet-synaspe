import SwiftUI
import AVKit
import UniformTypeIdentifiers

// MARK: - FCPXMLDocument (Export type pour Final Cut Pro XML)
@available(macOS 14.0, *)
struct FCPXMLDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.xml] }
    static var writableContentTypes: [UTType] { [.xml] }
    
    var xmlContent: String = ""
    
    init(xmlContent: String = "") {
        self.xmlContent = xmlContent
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let string = String(data: data, encoding: .utf8) {
            xmlContent = string
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = xmlContent.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

@available(macOS 14.0, *)
struct AutoDerushView: View {
    @StateObject private var derushEngine = AutoDerushEngine()
    @State private var selectedVideoURL: URL?
    @State private var derushResult: DerushResult?
    @State private var selectedSpeed: AutoDerushEngine.DerushSpeed = .medium
    @State private var silenceThreshold: Double = -40.0 // Seuil de silence réglable
    @State private var preserveMinDuration: Double = 0.5
    @State private var showingVideoPicker = false
    @State private var showingExportDialog = false
    @State private var exportType: ExportType = .video
    @State private var playheadPosition: TimeInterval = 0
    @State private var isPlaying = false
    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    
    enum ExportType {
        case video, fcpxml, timeline
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar - Contrôles
            DerushSidebarView(
                selectedVideoURL: $selectedVideoURL,
                selectedSpeed: $selectedSpeed,
                silenceThreshold: $silenceThreshold,
                preserveMinDuration: $preserveMinDuration,
                showingVideoPicker: $showingVideoPicker,
                onStartDerush: startDerush
            )
            .frame(minWidth: 300)
            
        } detail: {
            // Zone principale - Timeline et prévisualisation
            VStack(spacing: 0) {
                // Header
                DerushHeaderView(
                    derushResult: derushResult,
                    onExport: { type in
                        exportType = type
                        showingExportDialog = true
                    }
                )
                .frame(height: 60)
                .background(.ultraThinMaterial)
                
                if derushEngine.isProcessing {
                    // Vue de traitement
                    DerushProcessingView(
                        engine: derushEngine
                    )
                } else if let result = derushResult {
                    // Vue de résultat avec timeline + VRAI PLAYER
                    VStack(spacing: 0) {
                        // LECTEUR VIDÉO PREVIEW (avec composition dérushée)
                        if let player = player {
                            AVPlayerViewWrapper(player: player)
                                .frame(height: 300)
                        }
                        
                        // Timeline
                        DerushTimelineView(
                            result: result,
                            playheadPosition: $playheadPosition,
                            isPlaying: $isPlaying,
                            onSeek: seekToTime
                        )
                    }
                } else {
                    // Vue d'accueil
                    DerushWelcomeView(
                        onSelectVideo: { showingVideoPicker = true }
                    )
                }
            }
        }
        .navigationTitle("Auto-Dérush Synapse")
        .onChange(of: derushResult) { result in
            setupPreviewPlayer(result: result)
        }
        .onChange(of: isPlaying) { playing in
            if playing {
                player?.play()
            } else {
                player?.pause()
            }
        }
        .onDisappear {
            cleanupPlayer()
        }
        .fileImporter(
            isPresented: $showingVideoPicker,
            allowedContentTypes: [.movie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedVideoURL = url
                }
            case .failure(let error):
                print("Failed to import video: \(error)")
            }
        }
        .fileExporter(
            isPresented: $showingExportDialog,
            document: FCPXMLDocument(xmlContent: ""),
            contentType: .xml,
            defaultFilename: "derush_project.fcpxml"
        ) { result in
            switch result {
            case .success(let url):
                Task {
                    await handleExport(to: url)
                }
            case .failure(let error):
                print("Export failed: \(error)")
            }
        }
    }
    
    private func startDerush() {
        guard let videoURL = selectedVideoURL else { return }
        
        Task {
            do {
                derushResult = try await derushEngine.performAutoDerush(
                    videoURL: videoURL,
                    speed: selectedSpeed,
                    silenceThreshold: Float(silenceThreshold),
                    preserveMinDuration: preserveMinDuration
                )
            } catch {
                print("Dérush failed: \(error)")
            }
        }
    }
    
    // MARK: - Seek/Scrubbing
    private func seekToTime(_ time: TimeInterval) {
        let newTime = max(0, min(time, derushResult?.derushDuration ?? 0)) // Borner le temps
        playheadPosition = newTime // Mettre à jour l'UI
        
        // Mettre à jour le vrai lecteur vidéo
        let cmTime = CMTime(seconds: newTime, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    // MARK: - Player Management
    private func setupPreviewPlayer(result: DerushResult?) {
        cleanupPlayer()
        
        guard let result = result else { return }
        
        // Create composition from kept segments
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { return }
        
        let asset = AVAsset(url: result.originalURL)
        Task {
            guard let sourceVideoTrack = try? await asset.loadTracks(withMediaType: .video).first,
                  let sourceAudioTrack = try? await asset.loadTracks(withMediaType: .audio).first else { return }
            
            var currentTime = CMTime.zero
            
            for segment in result.derushSegments where segment.type == .kept {
                let startTime = CMTime(seconds: segment.originalStartTime, preferredTimescale: 600)
                let duration = CMTime(seconds: segment.duration, preferredTimescale: 600)
                let timeRange = CMTimeRange(start: startTime, duration: duration)
                
                try? videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: currentTime)
                try? audioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: currentTime)
                
                currentTime = CMTimeAdd(currentTime, duration)
            }
            
            DispatchQueue.main.async {
                let playerItem = AVPlayerItem(asset: composition)
                let newPlayer = AVPlayer(playerItem: playerItem)
                self.player = newPlayer
                
                let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
                self.timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) { time in
                    self.playheadPosition = time.seconds
                }
            }
        }
    }
    
    private func cleanupPlayer() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        player?.pause()
        player = nil
    }
    
    private func handleExport(to url: URL) async {
        guard let result = derushResult else { return }
        
        do {
            switch exportType {
            case .video:
                try await derushEngine.exportDerushVideo(result, outputURL: url)
            case .fcpxml:
                try await derushEngine.exportToFCPXML(result, outputURL: url)
            case .timeline:
                // TODO: Export vers timeline IA
                break
            }
        } catch {
            print("Export failed: \(error)")
        }
    }
}

// MARK: - Sidebar (2026 Modern Design - Optimized for compiler)
@available(macOS 14.0, *)
struct DerushSidebarView: View {
    @Binding var selectedVideoURL: URL?
    @Binding var selectedSpeed: AutoDerushEngine.DerushSpeed
    @Binding var silenceThreshold: Double
    @Binding var preserveMinDuration: Double
    @Binding var showingVideoPicker: Bool
    let onStartDerush: () -> Void
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.1),
                    Color(red: 0.12, green: 0.12, blue: 0.15)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SidebarHeaderView()
                    
                    Divider().opacity(0.3)
                    
                    SidebarVideoSection(
                        selectedVideoURL: $selectedVideoURL,
                        showingVideoPicker: $showingVideoPicker
                    )
                    
                    SidebarParametersSection(
                        selectedSpeed: $selectedSpeed,
                        silenceThreshold: $silenceThreshold,
                        preserveMinDuration: $preserveMinDuration
                    )
                    
                    SidebarActionButton(
                        isEnabled: selectedVideoURL != nil,
                        onStartDerush: onStartDerush
                    )
                    
                    Spacer()
                }
                .padding(16)
            }
        }
    }
}

@available(macOS 14.0, *)
struct SidebarHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Auto-Dérush", systemImage: "waveform.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [.purple, .pink]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("Intelligence audio avancée")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

@available(macOS 14.0, *)
struct SidebarVideoSection: View {
    @Binding var selectedVideoURL: URL?
    @Binding var showingVideoPicker: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Vidéo Source", systemImage: "film.fill")
                .font(.headline)
            
            if let url = selectedVideoURL {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(url.lastPathComponent)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text("Prêt pour l'analyse")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    
                    Button(action: { showingVideoPicker = true }) {
                        HStack {
                            Image(systemName: "arrow.2.squarepath")
                            Text("Changer")
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
            } else {
                Button(action: { showingVideoPicker = true }) {
                    VStack(spacing: 12) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 32))
                        VStack(spacing: 4) {
                            Text("Importer une vidéo")
                                .fontWeight(.semibold)
                            Text("MP4, MOV, etc.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1.5)
                            .background(Color.white.opacity(0.02))
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.purple)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

@available(macOS 14.0, *)
struct SidebarParametersSection: View {
    @Binding var selectedSpeed: AutoDerushEngine.DerushSpeed
    @Binding var silenceThreshold: Double
    @Binding var preserveMinDuration: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Paramètres de Détection", systemImage: "slider.horizontal.3")
                .font(.headline)
            
            SpeedParameter(selectedSpeed: $selectedSpeed)
            SensitivityParameter(silenceThreshold: $silenceThreshold)
            DurationParameter(preserveMinDuration: $preserveMinDuration)
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct SpeedParameter: View {
    @Binding var selectedSpeed: AutoDerushEngine.DerushSpeed
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Agressivité")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(selectedSpeed.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            Picker("Vitesse", selection: $selectedSpeed) {
                ForEach(AutoDerushEngine.DerushSpeed.allCases, id: \.self) { speed in
                    Text(speed.description.prefix(10)).tag(speed)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

struct SensitivityParameter: View {
    @Binding var silenceThreshold: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sensibilité")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                HStack(spacing: 4) {
                    Text("\(Int(silenceThreshold))")
                        .font(.system(.caption, design: .monospaced))
                    Text("dB")
                        .font(.caption2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            Slider(value: $silenceThreshold, in: -60...(-10), step: 1)
                .accentColor(.blue)
            HStack {
                Image(systemName: "info.circle")
                    .font(.caption)
                Text("Moins sensible = plus de coupures")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
    }
}

struct DurationParameter: View {
    @Binding var preserveMinDuration: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Durée Minimale")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                HStack(spacing: 2) {
                    Text(String(format: "%.1f", preserveMinDuration))
                        .font(.system(.caption, design: .monospaced))
                    Text("s")
                        .font(.caption2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            Slider(value: $preserveMinDuration, in: 0.2...2.0, step: 0.1)
                .accentColor(.purple)
        }
    }
}

@available(macOS 14.0, *)
struct SidebarActionButton: View {
    let isEnabled: Bool
    let onStartDerush: () -> Void
    
    var body: some View {
        Button(action: onStartDerush) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.headline)
                Text("Analyser & Dérush")
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.purple, .pink]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: Color.purple.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - Header
@available(macOS 14.0, *)
struct DerushHeaderView: View {
    let derushResult: DerushResult?
    let onExport: (AutoDerushView.ExportType) -> Void
    
    var body: some View {
        HStack {
            // Informations
            if let result = derushResult {
                HStack(spacing: 20) {
                    InfoBadge(
                        label: "Original",
                        value: formatDuration(result.originalDuration),
                        color: .gray
                    )
                    
                    InfoBadge(
                        label: "Dérushé",
                        value: formatDuration(result.derushDuration),
                        color: .green
                    )
                    
                    InfoBadge(
                        label: "Compression",
                        value: "\(Int(result.compressionRatio * 100))%",
                        color: .blue
                    )
                    
                    InfoBadge(
                        label: "Coupes",
                        value: "\(result.segmentsRemoved)",
                        color: .orange
                    )
                }
            } else {
                Text("Auto-Dérush Synapse")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            // Boutons d'export
            if derushResult != nil {
                HStack(spacing: 8) {
                    Menu {
                        Button("Exporter Vidéo") {
                            onExport(.video)
                        }
                        
                        Button("Exporter FCPXML") {
                            onExport(.fcpxml)
                        }
                        
                        Button("Vers Timeline IA") {
                            onExport(.timeline)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Exporter")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Processing View
@available(macOS 14.0, *)
struct DerushProcessingView: View {
    @ObservedObject var engine: AutoDerushEngine
    
    var body: some View {
        VStack(spacing: 30) {
            // Indicateur de progression
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(engine.progress))
                        .stroke(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: engine.progress)
                    
                    Text("\(Int(engine.progress * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
                
                VStack(spacing: 8) {
                    Text("Dérush en cours")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(engine.currentTask)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Étapes du processus
            VStack(alignment: .leading, spacing: 12) {
                ProcessStep(
                    title: "Analyse audio",
                    isCompleted: engine.progress > 0.3,
                    isCurrent: engine.progress <= 0.3
                )
                
                ProcessStep(
                    title: "Détection de parole",
                    isCompleted: engine.progress > 0.6,
                    isCurrent: engine.progress > 0.3 && engine.progress <= 0.6
                )
                
                ProcessStep(
                    title: "Génération des coupes",
                    isCompleted: engine.progress > 0.8,
                    isCurrent: engine.progress > 0.6 && engine.progress <= 0.8
                )
                
                ProcessStep(
                    title: "Création de la timeline",
                    isCompleted: engine.progress >= 1.0,
                    isCurrent: engine.progress > 0.8 && engine.progress < 1.0
                )
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.12, green: 0.12, blue: 0.13))
    }
}

// MARK: - Timeline View
@available(macOS 14.0, *)
struct DerushTimelineView: View {
    let result: DerushResult
    @Binding var playheadPosition: TimeInterval
    @Binding var isPlaying: Bool
    var onSeek: (TimeInterval) -> Void
    @State private var timelineScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Contrôles de lecture
            DerushPlaybackControls(
                result: result,
                playheadPosition: $playheadPosition,
                isPlaying: $isPlaying
            )
            .frame(height: 60)
            .background(.ultraThinMaterial)
            
            // Timeline avec zone tactile interactive
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .leading) {
                    VStack(spacing: 16) {
                        // Timeline originale
                        DerushTrackView(
                            title: "Original",
                            segments: result.derushSegments,
                            showRemoved: true,
                            scale: timelineScale,
                            playheadPosition: playheadPosition,
                            audioSamples: result.audioSamples
                        )
                        
                        // Timeline dérushée
                        DerushTrackView(
                            title: "Dérushé",
                            segments: result.derushSegments.filter { $0.type == .kept },
                            showRemoved: false,
                            scale: timelineScale,
                            playheadPosition: playheadPosition,
                            audioSamples: result.audioSamples
                        )
                    }
                    .padding()
                    
                    // Zone tactile invisible pour le scrubbing
                    GeometryReader { geometry in
                        Color.white.opacity(0.001) // Presque transparent mais interactif
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        // Calcul de la position : X / (Échelle * 50 pixels/sec)
                                        let pixelsPerSecond: CGFloat = 50.0 * timelineScale
                                        let time = value.location.x / pixelsPerSecond
                                        
                                        // Appeler la fonction de seek
                                        onSeek(time)
                                    }
                            )
                    }
                }
                .frame(minWidth: calculateTotalWidth(duration: result.derushDuration))
            }
            .background(Color(red: 0.08, green: 0.08, blue: 0.09))
            
            // Contrôles de zoom
            HStack {
                Button(action: { timelineScale = max(0.5, timelineScale - 0.2) }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                
                Text("\(Int(timelineScale * 100))%")
                    .frame(width: 50)
                    .font(.caption)
                
                Button(action: { timelineScale = min(3.0, timelineScale + 0.2) }) {
                    Image(systemName: "plus.magnifyingglass")
                }
                
                Spacer()
                
                Text("Segments conservés: \(result.derushSegments.filter { $0.type == .kept }.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
    
    // Fonction utilitaire pour calculer la largeur totale
    private func calculateTotalWidth(duration: TimeInterval) -> CGFloat {
        return CGFloat(duration) * timelineScale * 50.0 + 40 // + padding
    }
}

// MARK: - Helper Views
@available(macOS 14.0, *)
struct InfoBadge: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

@available(macOS 14.0, *)
struct ProcessStep: View {
    let title: String
    let isCompleted: Bool
    let isCurrent: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isCompleted ? .green : (isCurrent ? .purple : .gray.opacity(0.3)))
                    .frame(width: 20, height: 20)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                } else if isCurrent {
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                }
            }
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(isCurrent ? .primary : .secondary)
                .fontWeight(isCurrent ? .medium : .regular)
            
            Spacer()
        }
    }
}

@available(macOS 14.0, *)
struct DerushWelcomeView: View {
    let onSelectVideo: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "scissors.badge.ellipsis")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Auto-Dérush Intelligent")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Supprimez automatiquement les silences et gardez uniquement les moments de parole")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 600)
            }
            
            Button(action: onSelectVideo) {
                HStack {
                    Image(systemName: "video.badge.plus")
                    Text("Sélectionner une Vidéo")
                }
                .font(.title2)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.12, green: 0.12, blue: 0.13))
    }
}

@available(macOS 14.0, *)
struct DerushPlaybackControls: View {
    let result: DerushResult
    @Binding var playheadPosition: TimeInterval
    @Binding var isPlaying: Bool
    
    var body: some View {
        HStack {
            // Contrôles de lecture
            HStack(spacing: 16) {
                Button(action: { playheadPosition = 0 }) {
                    Image(systemName: "backward.end")
                }
                
                Button(action: { isPlaying.toggle() }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                }
                
                Button(action: { playheadPosition = result.derushDuration }) {
                    Image(systemName: "forward.end")
                }
            }
            
            Spacer()
            
            // Timecode
            Text("\(formatTime(playheadPosition)) / \(formatTime(result.derushDuration))")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

@available(macOS 14.0, *)
struct DerushTrackView: View {
    let title: String
    let segments: [DerushSegment]
    let showRemoved: Bool
    let scale: CGFloat
    let playheadPosition: TimeInterval
    let audioSamples: [Float]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            
            TrackTimelineArea(
                segments: segments,
                showRemoved: showRemoved,
                scale: scale,
                playheadPosition: playheadPosition,
                audioSamples: audioSamples
            )
        }
    }
}

@available(macOS 14.0, *)
struct TrackTimelineArea: View {
    let segments: [DerushSegment]
    let showRemoved: Bool
    let scale: CGFloat
    let playheadPosition: TimeInterval
    let audioSamples: [Float]
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Track background
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.15, green: 0.15, blue: 0.17),
                            Color(red: 0.12, green: 0.12, blue: 0.14)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
            
            // Segments
            HStack(spacing: 2) {
                ForEach(segments, id: \.id) { segment in
                    DerushSegmentView(
                        segment: segment,
                        scale: scale,
                        showRemoved: showRemoved,
                        audioSamples: extractAudioSamplesForSegment(segment)
                    )
                }
            }
            .padding(.horizontal, 4)
            
            // Playhead
            if !showRemoved {
                Rectangle()
                    .fill(.red)
                    .frame(width: 2, height: 80)
                    .offset(x: CGFloat(playheadPosition * scale * 50))
            }
        }
    }
    
    private func extractAudioSamplesForSegment(_ segment: DerushSegment) -> [Float] {
        guard !audioSamples.isEmpty else { return [] }
        let totalDuration = segments.reduce(0.0) { $0 + $1.duration }
        guard totalDuration > 0 else { return [] }
        let startRatio = segment.originalStartTime / totalDuration
        let endRatio = segment.originalEndTime / totalDuration
        let startIndex = Int(startRatio * Double(audioSamples.count))
        let endIndex = Int(endRatio * Double(audioSamples.count))
        let clampedStart = max(0, min(startIndex, audioSamples.count))
        let clampedEnd = max(clampedStart, min(endIndex, audioSamples.count))
        return Array(audioSamples[clampedStart..<clampedEnd])
    }
}

@available(macOS 14.0, *)
struct DerushSegmentView: View {
    let segment: DerushSegment
    let scale: CGFloat
    let showRemoved: Bool
    let audioSamples: [Float]
    
    var body: some View {
        let width = CGFloat(segment.duration * scale * 50)
        
        ZStack {
            // Waveform réelle en arrière-plan
            if !audioSamples.isEmpty {
                WaveformShape(samples: audioSamples)
                    .stroke(segmentColor.opacity(0.8), lineWidth: 1.5)
                    .background(segmentColor.opacity(0.2))
            } else {
                // Fallback si pas d'audio samples
                RoundedRectangle(cornerRadius: 4)
                    .fill(segmentColor.opacity(0.3))
            }
            
            // Texte overlay
            VStack(spacing: 2) {
                if width > 60 {
                    Text(formatDuration(segment.duration))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                    
                    if segment.type == .removed, let reason = segment.removalReason {
                        Text(reason)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.5), radius: 2)
                            .lineLimit(2)
                    }
                }
            }
            .padding(4)
        }
        .frame(width: max(width, 2), height: 70)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .opacity(segment.type == .removed && !showRemoved ? 0.3 : 1.0)
    }
    
    private var segmentColor: Color {
        switch segment.type {
        case .kept:
            return .green
        case .removed:
            return .red.opacity(0.7)
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        return String(format: "%.1fs", seconds)
    }
}