import AVFoundation
import Observation
import UIKit

/// Parent-controlled sound switches, remembered on this iPad.
@MainActor
@Observable
public final class SoundSettings {
    private let defaults: UserDefaults

    public var voiceEnabled: Bool { didSet { defaults.set(voiceEnabled, forKey: "sound.voice") } }
    public var effectsEnabled: Bool { didSet { defaults.set(effectsEnabled, forKey: "sound.effects") } }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        voiceEnabled = defaults.object(forKey: "sound.voice") as? Bool ?? true
        effectsEnabled = defaults.object(forKey: "sound.effects") as? Bool ?? true
    }
}

public enum FeedbackEffect: String, CaseIterable, Sendable {
    case tap, correct, wrong, pop, unlock, celebrate, page
}

/// Plays short interface sounds with a matching haptic.
@MainActor
@Observable
public final class FeedbackPlayer {
    @ObservationIgnored private var players: [FeedbackEffect: AVAudioPlayer] = [:]
    @ObservationIgnored private let settings: SoundSettings
    @ObservationIgnored private let light = UIImpactFeedbackGenerator(style: .light)
    @ObservationIgnored private let medium = UIImpactFeedbackGenerator(style: .medium)
    @ObservationIgnored private let notification = UINotificationFeedbackGenerator()

    public init(bundle: Bundle = .main, settings: SoundSettings = SoundSettings()) {
        self.settings = settings
        for effect in FeedbackEffect.allCases {
            guard let url = bundle.url(forResource: "sfx-\(effect.rawValue)", withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.volume = effect == .tap ? 0.35 : 0.55
            players[effect] = player
        }
    }

    public func play(_ effect: FeedbackEffect) {
        switch effect {
        case .tap, .page: light.impactOccurred()
        case .pop: medium.impactOccurred()
        case .correct, .unlock, .celebrate: notification.notificationOccurred(.success)
        case .wrong: notification.notificationOccurred(.warning)
        }
        guard settings.effectsEnabled, let player = players[effect] else { return }
        player.currentTime = 0
        player.play()
    }
}
