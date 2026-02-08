import SwiftUI

struct AnimatedBlindIcon: View {
    let iconType: BlindIconType
    let closureFraction: CGFloat
    let isMoving: Bool
    let tintColor: Color
    let size: CGFloat

    private let frameRate: TimeInterval = 1.0 / 15
    private let traversalSpeed: CGFloat = 1.0 / 20.0
    private let pulseAmplitude: CGFloat = 0.04
    private let pulseFrequency: CGFloat = 2.5

    @State private var animator: BlindAnimator

    init(iconType: BlindIconType, closureFraction: CGFloat, isMoving: Bool = false,
         tintColor: Color? = nil, size: CGFloat = 48) {
        self.iconType = iconType
        self.closureFraction = closureFraction
        self.isMoving = isMoving
        self.tintColor = tintColor ?? BlindColors.stateColor(closure: Int(closureFraction * 100), isMoving: isMoving)
        self.size = size
        let anim = BlindAnimator()
        anim.jumpTo(closureFraction)
        _animator = State(initialValue: anim)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: frameRate)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let fraction = animator.step(at: now)
            let starPhase = CGFloat(now.truncatingRemainder(dividingBy: 5.0) / 5.0)
            let isDaytime = SceneDrawing.currentIsDaytime
            let pulseScale = isMoving ? 1.0 + pulseAmplitude * CGFloat(sin(now * pulseFrequency)) : 1.0

            BlindIconView(
                iconType: iconType,
                closureFraction: fraction,
                tintColor: tintColor,
                size: size,
                isDaytime: isDaytime,
                starPhase: starPhase
            )
            .scaleEffect(pulseScale)
        }
        .onChange(of: closureFraction) { _, newValue in
            if isMoving {
                animator.setTarget(newValue, mode: .linear(speed: traversalSpeed))
            } else {
                animator.setTarget(newValue, mode: .spring)
            }
        }
        .onChange(of: isMoving) { _, moving in
            if !moving {
                animator.setTarget(closureFraction, mode: .spring)
            }
        }
    }
}
