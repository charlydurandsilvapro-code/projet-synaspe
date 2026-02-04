import SwiftUI

/// Animations contextuelles pour les interactions de timeline
@available(macOS 14.0, *)
extension View {
    /// Animation de "lift" quand un clip est déplacé
    func clipLiftEffect(isLifted: Bool) -> some View {
        self.modifier(ClipLiftModifier(isLifted: isLifted))
    }
    
    /// Animation de pulsation pour les beats audio
    func beatPulse(on beat: Bool, intensity: CGFloat = 1.0) -> some View {
        self.modifier(BeatPulseModifier(onBeat: beat, intensity: intensity))
    }
    
    /// Animation de magnétisme (snap to beat)
    func magneticSnap(isSnapping: Bool) -> some View {
        self.modifier(MagneticSnapModifier(isSnapping: isSnapping))
    }
}

// MARK: - Lift Modifier

@available(macOS 14.0, *)
struct ClipLiftModifier: ViewModifier {
    let isLifted: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isLifted ? 1.05 : 1.0)
            .shadow(
                color: isLifted ? .black.opacity(0.3) : .clear,
                radius: isLifted ? 15 : 0,
                y: isLifted ? 8 : 0
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isLifted)
    }
}

// MARK: - Beat Pulse Modifier

@available(macOS 14.0, *)
struct BeatPulseModifier: ViewModifier {
    let onBeat: Bool
    let intensity: CGFloat
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(onBeat ? 1.0 + (0.05 * intensity) : 1.0)
            .opacity(onBeat ? 1.0 : 0.85)
            .animation(.spring(response: 0.1, dampingFraction: 0.5), value: onBeat)
    }
}

// MARK: - Magnetic Snap Modifier

@available(macOS 14.0, *)
struct MagneticSnapModifier: ViewModifier {
    let isSnapping: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isSnapping ? 2 : 0
                    )
            )
            .animation(.spring(response: 0.15, dampingFraction: 0.8), value: isSnapping)
    }
}

// MARK: - Phase Animator Presets

@available(macOS 14.0, *)
enum ClipPhase: CaseIterable {
    case idle
    case lift
    case drag
    case drop
    
    var scale: CGFloat {
        switch self {
        case .idle: return 1.0
        case .lift: return 1.05
        case .drag: return 1.03
        case .drop: return 1.0
        }
    }
    
    var shadowRadius: CGFloat {
        switch self {
        case .idle: return 0
        case .lift: return 15
        case .drag: return 20
        case .drop: return 0
        }
    }
    
    var shadowY: CGFloat {
        switch self {
        case .idle: return 0
        case .lift: return 8
        case .drag: return 12
        case .drop: return 0
        }
    }
}

// MARK: - Phase Animated Clip View

@available(macOS 14.0, *)
struct PhaseAnimatedClip<Content: View>: View {
    @Binding var phase: ClipPhase
    let content: () -> Content
    
    var body: some View {
        PhaseAnimator(ClipPhase.allCases, trigger: phase) { currentPhase in
            content()
                .scaleEffect(currentPhase.scale)
                .shadow(
                    color: .black.opacity(0.3),
                    radius: currentPhase.shadowRadius,
                    y: currentPhase.shadowY
                )
        } animation: { phase in
            switch phase {
            case .lift:
                return .spring(response: 0.25, dampingFraction: 0.7)
            case .drag:
                return .interactiveSpring(response: 0.15, dampingFraction: 0.8)
            case .drop:
                return .spring(response: 0.35, dampingFraction: 0.6)
            default:
                return .default
            }
        }
    }
}

// MARK: - Transition Helpers

@available(macOS 14.0, *)
extension AnyTransition {
    /// Transition pour l'ajout/suppression de clips (comblement automatique)
    static var clipInsertion: AnyTransition {
        .asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        )
    }
    
    /// Transition fluide pour le réarrangement
    static var clipReorder: AnyTransition {
        .move(edge: .leading).combined(with: .opacity)
    }
}

// MARK: - Interpolation Utilities

@available(macOS 14.0, *)
extension Animation {
    /// Animation spring personnalisée pour les interactions timeline
    static var timelineSpring: Animation {
        .spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.1)
    }
    
    /// Animation pour le trim (réponse immédiate)
    static var trimResponse: Animation {
        .interactiveSpring(response: 0.15, dampingFraction: 0.85)
    }
    
    /// Animation pour le snap magnétique
    static var magneticSnap: Animation {
        .spring(response: 0.2, dampingFraction: 0.8)
    }
}

// MARK: - Haptic Feedback (macOS)

@available(macOS 14.0, *)
struct HapticFeedback {
    /// Feedback tactile lors d'un snap à un beat
    static func snapFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .default
        )
    }
    
    /// Feedback lors de la sélection d'un clip
    static func selectionFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .generic,
            performanceTime: .default
        )
    }
    
    /// Feedback lors de la suppression
    static func deletionFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .levelChange,
            performanceTime: .default
        )
    }
}
