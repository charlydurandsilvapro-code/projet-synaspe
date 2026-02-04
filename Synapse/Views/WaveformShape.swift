import SwiftUI

/// Shape personnalisée pour dessiner la waveform audio
@available(macOS 14.0, *)
struct WaveformShape: Shape {
    let samples: [Float]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        guard !samples.isEmpty else { return path }
        
        let width = rect.width
        let height = rect.height
        let midY = height / 2
        
        // Espacement entre chaque sample
        let spacing = width / CGFloat(samples.count)
        
        // Dessiner les barres verticales pour chaque sample
        for (index, sample) in samples.enumerated() {
            let x = CGFloat(index) * spacing
            
            // Normaliser l'amplitude (0-1)
            let normalizedSample = abs(sample)
            let barHeight = CGFloat(normalizedSample) * (height / 2)
            
            // Dessiner barre symétrique autour du centre
            path.move(to: CGPoint(x: x, y: midY - barHeight))
            path.addLine(to: CGPoint(x: x, y: midY + barHeight))
        }
        
        return path
    }
}
