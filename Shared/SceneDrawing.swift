import SwiftUI

enum SceneDrawing {
    static var currentIsDaytime: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 7 && hour < 20
    }

    static let starPositions: [(x: CGFloat, y: CGFloat, size: CGFloat, phase: CGFloat)] = [
        (0.15, 0.15, 1.5, 0.0), (0.82, 0.12, 2.0, 0.3),
        (0.38, 0.30, 1.2, 0.7), (0.65, 0.08, 1.8, 0.1),
        (0.22, 0.48, 1.0, 0.5), (0.90, 0.38, 1.5, 0.8),
        (0.50, 0.05, 1.3, 0.4), (0.08, 0.55, 1.0, 0.6),
        (0.75, 0.25, 1.8, 0.2), (0.45, 0.42, 1.2, 0.9),
    ]

    static func drawScene(context: GraphicsContext, in rect: CGRect, isDaytime: Bool, starPhase: CGFloat) {
        if isDaytime {
            drawDayScene(context: context, in: rect)
        } else {
            drawNightScene(context: context, in: rect, starPhase: starPhase)
        }
    }

    private static func drawDayScene(context: GraphicsContext, in rect: CGRect) {
        // Sky gradient
        let skyGradient = Gradient(colors: [
            Color(red: 0.30, green: 0.58, blue: 0.88),
            Color(red: 0.52, green: 0.78, blue: 0.98),
        ])
        context.fill(Path(rect), with: .linearGradient(
            skyGradient,
            startPoint: CGPoint(x: rect.midX, y: rect.minY),
            endPoint: CGPoint(x: rect.midX, y: rect.maxY)
        ))

        // Sun with glow
        let sunRadius = min(rect.width, rect.height) * 0.13
        let sunCenter = CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.minY + rect.height * 0.28)
        let glowRadius = sunRadius * 2.0
        let glowRect = CGRect(x: sunCenter.x - glowRadius, y: sunCenter.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)
        context.fill(Path(ellipseIn: glowRect), with: .color(Color(red: 1, green: 0.9, blue: 0.4).opacity(0.2)))
        let sunRect = CGRect(x: sunCenter.x - sunRadius, y: sunCenter.y - sunRadius, width: sunRadius * 2, height: sunRadius * 2)
        context.fill(Path(ellipseIn: sunRect), with: .color(Color(red: 1, green: 0.88, blue: 0.35)))

        // Cloud
        let cloudCenter = CGPoint(x: rect.minX + rect.width * 0.35, y: rect.minY + rect.height * 0.55)
        let s = min(rect.width, rect.height) * 0.025
        let cloudColor = Color.white.opacity(0.8)
        context.fill(Path(ellipseIn: CGRect(x: cloudCenter.x - s * 5, y: cloudCenter.y - s * 1.5, width: s * 10, height: s * 3.5)), with: .color(cloudColor))
        context.fill(Path(ellipseIn: CGRect(x: cloudCenter.x - s * 3, y: cloudCenter.y - s * 4, width: s * 6, height: s * 3.5)), with: .color(cloudColor))
        context.fill(Path(ellipseIn: CGRect(x: cloudCenter.x + s * 1, y: cloudCenter.y - s * 3, width: s * 4, height: s * 3)), with: .color(cloudColor))
    }

    private static func drawNightScene(context: GraphicsContext, in rect: CGRect, starPhase: CGFloat) {
        // Dark sky gradient
        let skyGradient = Gradient(colors: [
            Color(red: 0.04, green: 0.04, blue: 0.14),
            Color(red: 0.08, green: 0.06, blue: 0.22),
        ])
        context.fill(Path(rect), with: .linearGradient(
            skyGradient,
            startPoint: CGPoint(x: rect.midX, y: rect.minY),
            endPoint: CGPoint(x: rect.midX, y: rect.maxY)
        ))

        // Stars with twinkling
        for star in starPositions {
            let x = rect.minX + rect.width * star.x
            let y = rect.minY + rect.height * star.y
            let twinkle = 0.4 + 0.6 * (0.5 + 0.5 * sin(starPhase * .pi * 2 + star.phase * .pi * 2))
            let starRect = CGRect(x: x - star.size / 2, y: y - star.size / 2, width: star.size, height: star.size)
            context.fill(Path(ellipseIn: starRect), with: .color(.white.opacity(twinkle)))
        }

        // Crescent moon
        let moonRadius = min(rect.width, rect.height) * 0.1
        let moonCenter = CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.minY + rect.height * 0.22)
        // Moon glow
        let glowRadius = moonRadius * 2
        let glowRect = CGRect(x: moonCenter.x - glowRadius, y: moonCenter.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)
        context.fill(Path(ellipseIn: glowRect), with: .color(Color(red: 0.85, green: 0.88, blue: 0.95).opacity(0.08)))
        // Full circle
        let moonRect = CGRect(x: moonCenter.x - moonRadius, y: moonCenter.y - moonRadius, width: moonRadius * 2, height: moonRadius * 2)
        context.fill(Path(ellipseIn: moonRect), with: .color(Color(red: 0.92, green: 0.90, blue: 0.82)))
        // Crescent cut (overlay with sky color)
        let cutOffset = moonRadius * 0.55
        let cutRect = CGRect(x: moonCenter.x - moonRadius + cutOffset, y: moonCenter.y - moonRadius - cutOffset * 0.4, width: moonRadius * 2, height: moonRadius * 2)
        context.fill(Path(ellipseIn: cutRect), with: .color(Color(red: 0.06, green: 0.05, blue: 0.18)))
    }
}
