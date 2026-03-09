import AudioToolbox
import Foundation

final class SoundService {
    static let shared = SoundService()

    private init() {}

    private var isEnabled: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "soundEnabled") == nil {
            return true
        }
        return defaults.bool(forKey: "soundEnabled")
    }

    func playCorrect() {
        play(systemSoundID: 1025)
    }

    func playWrong() {
        play(systemSoundID: 1521)
    }

    func playComplete() {
        play(systemSoundID: 1026)
    }

    func playTap() {
        play(systemSoundID: 1104)
    }

    private func play(systemSoundID: SystemSoundID) {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(systemSoundID)
    }
}
