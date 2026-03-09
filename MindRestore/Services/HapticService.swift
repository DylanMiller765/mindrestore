import UIKit

enum HapticService {
    static func correct() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func wrong() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func complete() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func levelUp() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func tap() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func streak() {
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            gen.impactOccurred(intensity: 0.7)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            gen.impactOccurred(intensity: 0.4)
        }
    }
}
