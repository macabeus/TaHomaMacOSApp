import SwiftUI

// MARK: - Estore Icon (Portuguese exterior roller shutter)

struct EstoreIcon: View {
    let closureFraction: CGFloat
    let tintColor: Color
    let size: CGFloat
    var isDaytime: Bool = SceneDrawing.currentIsDaytime
    var starPhase: CGFloat = 0

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let housingHeight = h * 0.15
            let windowTop = housingHeight
            let windowBottom = h - h * 0.05
            let windowHeight = windowBottom - windowTop
            let margin = w * 0.1
            let windowLeft = margin
            let windowRight = w - margin
            let windowRect = CGRect(x: windowLeft, y: windowTop, width: windowRight - windowLeft, height: windowHeight)

            // Scene behind the window (full area — slats will cover from top)
            SceneDrawing.drawScene(context: context, in: windowRect, isDaytime: isDaytime, starPhase: starPhase)

            // Window cross-bars (visible in uncovered area)
            let uncoveredFraction = 1.0 - closureFraction
            if uncoveredFraction > 0.1 {
                let crossOpacity = Double(uncoveredFraction) * 0.35
                let coveredBottom = windowTop + windowHeight * closureFraction
                let midX = (windowLeft + windowRight) / 2
                let midY = coveredBottom + (windowBottom - coveredBottom) / 2

                var vPath = Path()
                vPath.move(to: CGPoint(x: midX, y: coveredBottom))
                vPath.addLine(to: CGPoint(x: midX, y: windowBottom))
                context.stroke(vPath, with: .color(tintColor.opacity(crossOpacity)), lineWidth: 1)

                if midY > coveredBottom + 2 {
                    var hPath = Path()
                    hPath.move(to: CGPoint(x: windowLeft, y: midY))
                    hPath.addLine(to: CGPoint(x: windowRight, y: midY))
                    context.stroke(hPath, with: .color(tintColor.opacity(crossOpacity)), lineWidth: 1)
                }
            }

            // Slats rolling down from housing
            let maxSlats = 12
            let slatCount = Int(CGFloat(maxSlats) * closureFraction)
            let slatAreaHeight = windowHeight * closureFraction
            if slatCount > 0 {
                let slatHeight = slatAreaHeight / CGFloat(slatCount)
                for i in 0..<slatCount {
                    let y = windowTop + CGFloat(i) * slatHeight
                    let slatRect = CGRect(x: windowLeft + 1, y: y, width: windowRight - windowLeft - 2, height: slatHeight - 1)
                    let brightness = (i % 2 == 0) ? 0.85 : 0.75
                    context.fill(Path(slatRect), with: .color(tintColor.opacity(brightness)))

                    var hlPath = Path()
                    hlPath.move(to: CGPoint(x: slatRect.minX, y: slatRect.minY + 0.5))
                    hlPath.addLine(to: CGPoint(x: slatRect.maxX, y: slatRect.minY + 0.5))
                    context.stroke(hlPath, with: .color(.white.opacity(0.25)), lineWidth: 0.5)
                }
            }

            // Housing box
            let housingRect = CGRect(x: windowLeft - 2, y: 0, width: windowRight - windowLeft + 4, height: housingHeight)
            context.fill(Path(roundedRect: housingRect, cornerRadius: 3), with: .color(tintColor.opacity(0.9)))
            context.stroke(Path(roundedRect: housingRect, cornerRadius: 3), with: .color(tintColor), lineWidth: 1)
            var detailLine = Path()
            detailLine.move(to: CGPoint(x: housingRect.minX + 3, y: housingHeight * 0.6))
            detailLine.addLine(to: CGPoint(x: housingRect.maxX - 3, y: housingHeight * 0.6))
            context.stroke(detailLine, with: .color(.white.opacity(0.3)), lineWidth: 0.5)

            // Window frame outline
            context.stroke(Path(windowRect), with: .color(tintColor.opacity(0.5)), lineWidth: 1.5)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Vertical Blind Icon (interior vertical slats)

struct VerticalBlindIcon: View {
    let closureFraction: CGFloat
    let tintColor: Color
    let size: CGFloat
    var isDaytime: Bool = SceneDrawing.currentIsDaytime
    var starPhase: CGFloat = 0

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let railHeight = h * 0.08
            let margin = w * 0.08
            let slatAreaLeft = margin
            let slatAreaRight = w - margin
            let slatAreaWidth = slatAreaRight - slatAreaLeft
            let slatTop = railHeight + 2
            let slatBottom = h - h * 0.05
            let sceneRect = CGRect(x: slatAreaLeft, y: slatTop, width: slatAreaWidth, height: slatBottom - slatTop)

            // Scene behind the slats
            SceneDrawing.drawScene(context: context, in: sceneRect, isDaytime: isDaytime, starPhase: starPhase)

            // Vertical slats
            let slatCount = 7
            let apparentWidth = sin(closureFraction * .pi / 2)
            let maxSlatWidth = slatAreaWidth / CGFloat(slatCount) * 0.95
            let minSlatWidth: CGFloat = 2
            let slatWidth = minSlatWidth + (maxSlatWidth - minSlatWidth) * apparentWidth
            let slatSpacing = slatAreaWidth / CGFloat(slatCount)

            for i in 0..<slatCount {
                let centerX = slatAreaLeft + slatSpacing * (CGFloat(i) + 0.5)
                let skewOffset = (1.0 - apparentWidth) * 2

                var slatPath = Path()
                slatPath.move(to: CGPoint(x: centerX - slatWidth / 2 + skewOffset, y: slatTop))
                slatPath.addLine(to: CGPoint(x: centerX + slatWidth / 2 + skewOffset, y: slatTop))
                slatPath.addLine(to: CGPoint(x: centerX + slatWidth / 2 - skewOffset, y: slatBottom))
                slatPath.addLine(to: CGPoint(x: centerX - slatWidth / 2 - skewOffset, y: slatBottom))
                slatPath.closeSubpath()

                let brightness = (i % 2 == 0) ? 0.7 : 0.6
                context.fill(slatPath, with: .color(tintColor.opacity(brightness)))
                context.stroke(slatPath, with: .color(tintColor.opacity(0.9)), lineWidth: 0.5)
            }

            // Header rail
            let railRect = CGRect(x: margin - 2, y: 0, width: slatAreaWidth + 4, height: railHeight)
            context.fill(Path(railRect), with: .color(tintColor.opacity(0.8)))
            context.stroke(Path(railRect), with: .color(tintColor), lineWidth: 1)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Skylight Blind Icon (angled roof window)

struct SkylightBlindIcon: View {
    let closureFraction: CGFloat
    let tintColor: Color
    let size: CGFloat
    var isDaytime: Bool = SceneDrawing.currentIsDaytime
    var starPhase: CGFloat = 0

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let tiltAngle: CGFloat = 0.12
            let margin = w * 0.12

            let topLeft = CGPoint(x: margin + w * tiltAngle, y: h * 0.05)
            let topRight = CGPoint(x: w - margin + w * tiltAngle, y: h * 0.05)
            let bottomRight = CGPoint(x: w - margin - w * tiltAngle, y: h * 0.95)
            let bottomLeft = CGPoint(x: margin - w * tiltAngle, y: h * 0.95)
            let frameWidth = topRight.x - topLeft.x
            let frameHeight = bottomLeft.y - topLeft.y

            // Clip to parallelogram and draw scene
            var framePath = Path()
            framePath.move(to: topLeft)
            framePath.addLine(to: topRight)
            framePath.addLine(to: bottomRight)
            framePath.addLine(to: bottomLeft)
            framePath.closeSubpath()

            // Draw scene in full window, clipped
            context.drawLayer { layerCtx in
                layerCtx.clip(to: framePath)
                let sceneRect = CGRect(x: min(topLeft.x, bottomLeft.x), y: topLeft.y,
                                       width: max(topRight.x, bottomRight.x) - min(topLeft.x, bottomLeft.x),
                                       height: frameHeight)
                SceneDrawing.drawScene(context: layerCtx, in: sceneRect, isDaytime: isDaytime, starPhase: starPhase)
            }

            // Fabric area covering from top
            let fabricBottom = topLeft.y + frameHeight * closureFraction
            if closureFraction > 0.02 {
                var fabricPath = Path()
                fabricPath.move(to: topLeft)
                fabricPath.addLine(to: topRight)
                fabricPath.addLine(to: CGPoint(x: lerp(topRight.x, bottomRight.x, closureFraction), y: fabricBottom))
                fabricPath.addLine(to: CGPoint(x: lerp(topLeft.x, bottomLeft.x, closureFraction), y: fabricBottom))
                fabricPath.closeSubpath()
                context.fill(fabricPath, with: .color(tintColor.opacity(0.65)))

                // Texture lines
                let stripeCount = max(2, Int(closureFraction * 8))
                let fabricHeight = fabricBottom - topLeft.y
                for i in 1..<stripeCount {
                    let frac = CGFloat(i) / CGFloat(stripeCount)
                    let y = topLeft.y + fabricHeight * frac
                    let lx = lerp(topLeft.x, bottomLeft.x, closureFraction * frac)
                    let rx = lerp(topRight.x, bottomRight.x, closureFraction * frac)
                    var sp = Path()
                    sp.move(to: CGPoint(x: lx, y: y))
                    sp.addLine(to: CGPoint(x: rx, y: y))
                    context.stroke(sp, with: .color(tintColor.opacity(0.3)), lineWidth: 0.5)
                }

                // Pull bar
                let barLeft = lerp(topLeft.x, bottomLeft.x, closureFraction) + 3
                let barRight = lerp(topRight.x, bottomRight.x, closureFraction) - 3
                let barRect = CGRect(x: barLeft, y: fabricBottom - 2, width: barRight - barLeft, height: 3)
                context.fill(Path(barRect), with: .color(tintColor.opacity(0.9)))
            }

            // Roller cylinder
            let rollerRect = CGRect(x: topLeft.x - 1, y: topLeft.y - 2, width: frameWidth + 2, height: 5)
            context.fill(Path(roundedRect: rollerRect, cornerRadius: 2), with: .color(tintColor.opacity(0.85)))

            // Frame outline
            context.stroke(framePath, with: .color(tintColor.opacity(0.6)), lineWidth: 1.5)
        }
        .frame(width: size, height: size)
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
}

// MARK: - BlindIconView (router)

struct BlindIconView: View {
    let iconType: BlindIconType
    let closureFraction: CGFloat
    let tintColor: Color
    let size: CGFloat
    var isDaytime: Bool = SceneDrawing.currentIsDaytime
    var starPhase: CGFloat = 0

    init(iconType: BlindIconType, closureFraction: CGFloat, tintColor: Color? = nil, size: CGFloat = 48,
         isDaytime: Bool = SceneDrawing.currentIsDaytime, starPhase: CGFloat = 0) {
        self.iconType = iconType
        self.closureFraction = closureFraction
        self.tintColor = tintColor ?? BlindColors.stateColor(closure: Int(closureFraction * 100), isMoving: false)
        self.size = size
        self.isDaytime = isDaytime
        self.starPhase = starPhase
    }

    var body: some View {
        switch iconType {
        case .estore:
            EstoreIcon(closureFraction: closureFraction, tintColor: tintColor, size: size, isDaytime: isDaytime, starPhase: starPhase)
        case .verticalBlind:
            VerticalBlindIcon(closureFraction: closureFraction, tintColor: tintColor, size: size, isDaytime: isDaytime, starPhase: starPhase)
        case .skylightBlind:
            SkylightBlindIcon(closureFraction: closureFraction, tintColor: tintColor, size: size, isDaytime: isDaytime, starPhase: starPhase)
        }
    }
}
