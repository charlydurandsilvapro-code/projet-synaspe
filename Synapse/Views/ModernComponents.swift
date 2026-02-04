import SwiftUI

// MARK: - Modern Action Button
@available(macOS 14.0, *)
struct ModernActionButton: View {
    let title: String
    let icon: String
    let color: Color
    var isPrimary: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, isPrimary ? 24 : 16)
            .padding(.vertical, isPrimary ? 12 : 10)
            .background(
                RoundedRectangle(cornerRadius: isPrimary ? 12 : 8)
                    .fill(
                        isPrimary ? 
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [color.opacity(0.2), color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: isPrimary ? 12 : 8)
                            .stroke(color.opacity(isPrimary ? 0.0 : 0.3), lineWidth: 1)
                    )
            )
            .foregroundStyle(isPrimary ? .white : color)
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Animated Background
@available(macOS 14.0, *)
struct AnimatedBackgroundView: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Base dark background
            Color(red: 0.12, green: 0.12, blue: 0.13)
                .ignoresSafeArea()
            
            // Animated gradient orbs
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.purple.opacity(0.3),
                                Color.pink.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(
                        x: cos(animationOffset + Double(index) * 2.0) * 100,
                        y: sin(animationOffset + Double(index) * 1.5) * 80
                    )
                    .blur(radius: 60)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                animationOffset = .pi * 2
            }
        }
    }
}

// MARK: - Modern Sidebar
@available(macOS 14.0, *)
struct ModernSidebarView: View {
    @ObservedObject var viewModel: ProjectViewModel
    @State private var selectedSection: SidebarSection = .project
    
    enum SidebarSection: String, CaseIterable {
        case project = "Projet"
        case media = "Médias"
        case effects = "Effets"
        case settings = "Réglages"
        
        var icon: String {
            switch self {
            case .project: return "folder"
            case .media: return "photo.on.rectangle.angled"
            case .effects: return "wand.and.stars"
            case .settings: return "gearshape"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Section Tabs
            HStack(spacing: 0) {
                ForEach(SidebarSection.allCases, id: \.self) { section in
                    Button(action: { selectedSection = section }) {
                        VStack(spacing: 4) {
                            Image(systemName: section.icon)
                                .font(.system(size: 16))
                            
                            Text(section.rawValue)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(selectedSection == section ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selectedSection == section ?
                            Color.purple.opacity(0.3) : Color.clear
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(.ultraThinMaterial)
            
            Divider()
            
            // Content Area
            ScrollView {
                LazyVStack(spacing: 12) {
                    switch selectedSection {
                    case .project:
                        ProjectSectionView(viewModel: viewModel)
                    case .media:
                        MediaSectionView(viewModel: viewModel)
                    case .effects:
                        EffectsSectionView(viewModel: viewModel)
                    case .settings:
                        SettingsSectionView(viewModel: viewModel)
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Sidebar Sections
@available(macOS 14.0, *)
struct ProjectSectionView: View {
    @ObservedObject var viewModel: ProjectViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Informations Projet")
                .font(.headline)
                .foregroundStyle(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Vidéos", value: "\(viewModel.videoURLs.count)")
                InfoRow(label: "Segments", value: "\(viewModel.project.timeline.count)")
                InfoRow(label: "Durée", value: formatDuration(viewModel.project.timeline.reduce(0) { $0 + $1.timeRange.duration.seconds }))
                InfoRow(label: "Modifié", value: formatDate(viewModel.project.modifiedAt))
                
                if let audioAnalysis = viewModel.detailedAudioAnalysis {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Analyse Audio Avancée")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        InfoRow(label: "BPM", value: String(format: "%.1f", audioAnalysis.bpm))
                        InfoRow(label: "Beats", value: "\(audioAnalysis.beatGrid.count)")
                        InfoRow(label: "Confiance", value: String(format: "%.0f%%", audioAnalysis.confidence * 100))
                        
                        // Indicateur d'énergie
                        HStack {
                            Text("Énergie")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            HStack(spacing: 2) {
                                ForEach(0..<5, id: \.self) { index in
                                    Rectangle()
                                        .fill(index < Int(audioAnalysis.confidence * 5) ? Color.green : Color.gray.opacity(0.3))
                                        .frame(width: 3, height: 8)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                
                if let rushResult = viewModel.autoRushResult {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Résultat Auto-Rush")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        InfoRow(label: "Confiance", value: String(format: "%.0f%%", rushResult.confidence * 100))
                        InfoRow(label: "Compression", value: String(format: "%.1fx", rushResult.metadata.compressionRatio))
                        InfoRow(label: "Qualité Moy.", value: String(format: "%.1f", rushResult.metadata.averageQuality))
                        
                        if !rushResult.suggestions.isEmpty {
                            Text("Suggestions:")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                            
                            ForEach(rushResult.suggestions.prefix(2), id: \.self) { suggestion in
                                Text("• \(suggestion)")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            
            Divider()
            
            VStack(spacing: 8) {
                ModernActionButton(
                    title: "Nouveau Projet",
                    icon: "plus.circle",
                    color: .blue,
                    action: { /* TODO */ }
                )
                
                ModernActionButton(
                    title: "Sauvegarder",
                    icon: "square.and.arrow.down",
                    color: .green,
                    action: { /* TODO */ }
                )
                
                if viewModel.enableSmartFeatures && viewModel.audioURL != nil {
                    ModernActionButton(
                        title: "Analyser Audio",
                        icon: "waveform.circle",
                        color: .orange,
                        action: {
                            Task {
                                await viewModel.analyzeAudioInRealTime()
                            }
                        }
                    )
                }
                
                ModernActionButton(
                    title: "Auto-Dérush",
                    icon: "scissors.badge.ellipsis",
                    color: .cyan,
                    action: {
                        NotificationCenter.default.post(name: .openAutoDerush, object: nil)
                    }
                )
            }
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

@available(macOS 14.0, *)
struct MediaSectionView: View {
    @ObservedObject var viewModel: ProjectViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bibliothèque Médias")
                .font(.headline)
                .foregroundStyle(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(viewModel.previewSegments, id: \.id) { segment in
                    MediaThumbnailView(segment: segment, viewModel: viewModel)
                }
            }
        }
    }
}

@available(macOS 14.0, *)
struct EffectsSectionView: View {
    @ObservedObject var viewModel: ProjectViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Profils Couleur")
                .font(.headline)
                .foregroundStyle(.primary)
            
            VStack(spacing: 8) {
                ForEach(ColorProfile.allCases, id: \.self) { profile in
                    ColorProfileButton(
                        profile: profile,
                        isSelected: viewModel.project.globalColorProfile == profile,
                        action: { viewModel.changeColorProfile(profile) }
                    )
                }
            }
        }
    }
}

@available(macOS 14.0, *)
struct SettingsSectionView: View {
    @ObservedObject var viewModel: ProjectViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Paramètres")
                .font(.headline)
                .foregroundStyle(.primary)
            
            VStack(spacing: 12) {
                Toggle("Fonctionnalités IA Avancées", isOn: $viewModel.enableSmartFeatures)
                    .toggleStyle(.switch)
                    .help("Active l'analyse audio FFT et les coupes intelligentes")
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Plateforme Cible")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Picker("Plateforme", selection: $viewModel.selectedPlatform) {
                        ForEach(SocialPlatform.allCases, id: \.self) { platform in
                            Text(platform.rawValue).tag(platform)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                if viewModel.enableSmartFeatures {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Préférences Auto-Rush")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Seuil de Qualité")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(viewModel.rushPreferences.highlightThreshold * 100))%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            
                            Slider(
                                value: Binding(
                                    get: { viewModel.rushPreferences.highlightThreshold },
                                    set: { newValue in
                                        viewModel.updateRushPreferences(highlightThreshold: newValue)
                                    }
                                ),
                                in: 0.3...0.9,
                                step: 0.1
                            )
                            .accentColor(.purple)
                        }
                        
                        Toggle("Privilégier les Visages", isOn: Binding(
                            get: { viewModel.rushPreferences.preferFaces },
                            set: { newValue in
                                viewModel.updateRushPreferences(preferFaces: newValue)
                            }
                        ))
                        .toggleStyle(.switch)
                        .font(.caption)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Préférence de Mouvement")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Picker("Mouvement", selection: Binding(
                                get: { viewModel.rushPreferences.motionPreference },
                                set: { newValue in
                                    viewModel.updateRushPreferences(motionPreference: newValue)
                                }
                            )) {
                                Text("Faible").tag(MotionPreference.low)
                                Text("Équilibré").tag(MotionPreference.balanced)
                                Text("Élevé").tag(MotionPreference.high)
                            }
                            .pickerStyle(.segmented)
                            .font(.caption2)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

// MARK: - Helper Views
@available(macOS 14.0, *)
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
    }
}

@available(macOS 14.0, *)
struct MediaThumbnailView: View {
    let segment: VideoSegment
    @ObservedObject var viewModel: ProjectViewModel
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(16/9, contentMode: .fit)
                
                if let thumbnail = viewModel.thumbnails[segment.id] {
                    Image(thumbnail, scale: 1.0, label: Text("Thumbnail"))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "video")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                
                // Quality score overlay
                VStack {
                    HStack {
                        Spacer()
                        Text(String(format: "%.1f", segment.qualityScore))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    Spacer()
                }
                .padding(4)
            }
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
            
            Text(segment.sourceURL.lastPathComponent)
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
    }
}

@available(macOS 14.0, *)
struct ColorProfileButton: View {
    let profile: ColorProfile
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Circle()
                    .fill(profile.previewColor)
                    .frame(width: 16, height: 16)
                
                Text(profile.displayName)
                    .font(.subheadline)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.2) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color Profile Extension
extension ColorProfile {
    var displayName: String {
        switch self {
        case .cinematic: return "Cinématique"
        case .vivid: return "Éclatant"
        case .blackAndWhite: return "Noir & Blanc"
        case .natural: return "Naturel"
        }
    }
    
    var previewColor: Color {
        switch self {
        case .cinematic: return .orange
        case .vivid: return .pink
        case .blackAndWhite: return .gray
        case .natural: return .green
        }
    }
}