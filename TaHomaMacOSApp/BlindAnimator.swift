import Foundation

final class BlindAnimator {
    private(set) var current: CGFloat = 0
    private var target: CGFloat = 0
    private var velocity: CGFloat = 0
    private var lastTime: TimeInterval = 0
    private var mode: Mode = .spring

    enum Mode {
        case spring
        case linear(speed: CGFloat)
    }

    func jumpTo(_ value: CGFloat) {
        current = value
        target = value
        velocity = 0
        lastTime = 0
    }

    func setTarget(_ value: CGFloat, mode: Mode) {
        target = value
        self.mode = mode
        if case .linear = mode {
            velocity = 0
        }
    }

    func step(at time: TimeInterval) -> CGFloat {
        guard lastTime > 0 else {
            lastTime = time
            return current
        }
        let dt = CGFloat(min(time - lastTime, 0.1))
        lastTime = time

        switch mode {
        case .linear(let speed):
            let remaining = target - current
            let maxStep = speed * dt
            if abs(remaining) <= maxStep {
                current = target
            } else {
                current += remaining > 0 ? maxStep : -maxStep
            }
        case .spring:
            let stiffness: CGFloat = 80
            let damping: CGFloat = 12
            let force = stiffness * (target - current) - damping * velocity
            velocity += force * dt
            current += velocity * dt
            if abs(current - target) < 0.001 && abs(velocity) < 0.001 {
                current = target
                velocity = 0
            }
        }
        return current
    }
}
