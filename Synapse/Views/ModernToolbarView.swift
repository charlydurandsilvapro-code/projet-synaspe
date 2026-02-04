import SwiftUI

@available(macOS 14.0, *)
struct ModernToolbarView: View {
    @ObservedObject var viewModel: ProjectViewModel
    @Binding var selectedTab: ContentView.MainTab
    @Binding var showingSidebar: Bool
    @State private var showingExportDialog = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Left Section - Navigation
            HStack(spacing: 12) {
                // Sidebar Toggle
                Button(action: { showingSidebar.toggle() }) {
                    Image(systemName: showingSidebar ? "sidebar.left" : "sidebar.left")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .help("Afficher/Masquer la barre latérale")
                
                Divider()
                    .frame(height: 20)
                
                // Tab Navigation
                HStack(spacing: 8) {
                    ForEach(ContentView.MainTab.allCases, id: \.self) { tab in
                        ToolbarTabButton(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            action: { selectedTab = tab }
                        )
                    }
                }
            }
            
            Spacer()
            
            // Center Section - Playback Controls
            HStack(spacing: 12) {
                PlaybackControlButton(icon: "backward.end", action: { /* TODO */ })
                PlaybackControlButton(icon: "play.fill", action: { /* TODO */ }, isPrimary: true)
                PlaybackControlButton(icon: "forward.end", action: { /* TODO */ })
                
                Divider()
                    .frame(height: 20)
                
                // Timeline Position
                Text("00:00 / 02:30")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Right Section - Actions
            HStack(spacing: 8) {
                // Quick Actions
                ToolbarActionButton(
                    icon: "wand.and.stars",
                    tooltip: "Remplissage automatique",
                    action: {
                        Task {
                            await viewModel.autoFillTimeline()
                        }
                    }
                )
                
                ToolbarActionButton(
                    icon: "arrow.clockwise",
                    tooltip: "Actualiser les vignettes",
                    action: {
                        Task {
                            await viewModel.refreshThumbnails()
                        }
                    }
                )
                
                Divider()
                    .frame(height: 20)
                
                // Export Button
                Button(action: { showingExportDialog = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                        Text("Exporter")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.project.timeline.isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial)
        .fileExporter(
            isPresented: $showingExportDialog,
            document: TextDocument(text: ""),
            contentType: .mpeg4Movie,
            defaultFilename: "synapse_export.mp4"
        ) { result in
            switch result {
            case .success(let url):
                Task {
                    await viewModel.exportProject(to: url)
                }
            case .failure(let error):
                print("Export failed: \(error)")
            }
        }
    }
}

// MARK: - Toolbar Components
@available(macOS 14.0, *)
struct ToolbarTabButton: View {
    let tab: ContentView.MainTab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14))
                
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isSelected ? 
                        Color.purple.opacity(0.3) :
                        (isHovered ? Color.white.opacity(0.1) : Color.clear)
                    )
            )
            .foregroundStyle(isSelected ? .white : .secondary)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

@available(macOS 14.0, *)
struct PlaybackControlButton: View {
    let icon: String
    let action: () -> Void
    var isPrimary: Bool = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: isPrimary ? 18 : 16))
                .foregroundStyle(isPrimary ? .white : .primary)
                .frame(width: isPrimary ? 36 : 28, height: isPrimary ? 36 : 28)
                .background(
                    Group {
                        if isPrimary {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        } else {
                            Circle()
                                .fill(isHovered ? Color.white.opacity(0.1) : Color.clear)
                        }
                    }
                )
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.spring(response: 0.3), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

@available(macOS 14.0, *)
struct ToolbarActionButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.white.opacity(0.1) : Color.clear)
                )
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.spring(response: 0.3), value: isHovered)
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}