import Foundation

public struct AppIdentity: Sendable, Equatable {
    public let applicationIdentifier: String
    public let displayName: String
    public let childFacingName: String
    public let iconAssetName: String
    public let splashAssetName: String

    public init(applicationIdentifier: String, displayName: String, childFacingName: String, iconAssetName: String, splashAssetName: String) {
        self.applicationIdentifier = applicationIdentifier
        self.displayName = displayName
        self.childFacingName = childFacingName
        self.iconAssetName = iconAssetName
        self.splashAssetName = splashAssetName
    }
}

public struct ThemeTokens: Sendable, Equatable {
    public let background: [String]
    public let primary: String
    public let secondary: String
    public let success: String
    public let surface: String

    public init(background: [String], primary: String, secondary: String, success: String, surface: String) {
        self.background = background
        self.primary = primary
        self.secondary = secondary
        self.success = success
        self.surface = surface
    }
}

public struct ContentPackDescriptor: Sendable, Equatable {
    public let id: String
    public let version: Int
    public let resourceName: String

    public init(id: String, version: Int, resourceName: String) {
        self.id = id
        self.version = version
        self.resourceName = resourceName
    }
}

public struct LearningLocation: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let symbol: String

    public init(id: String, name: String, symbol: String) {
        self.id = id
        self.name = name
        self.symbol = symbol
    }
}

public struct LearningCharacter: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let locationID: String

    public init(id: String, name: String, locationID: String) {
        self.id = id
        self.name = name
        self.locationID = locationID
    }
}

public struct EducationalSkill: Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let displayName: String

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

public struct NarrationSettings: Sendable, Equatable {
    public let language: String
    public let normalRate: Float
    public let slowRate: Float
    public let pitch: Float
    public let bundledManifestName: String?

    public init(language: String = "en-US", normalRate: Float = 0.48, slowRate: Float = 0.38, pitch: Float = 1.03, bundledManifestName: String? = nil) {
        self.language = language
        self.normalRate = normalRate
        self.slowRate = slowRate
        self.pitch = pitch
        self.bundledManifestName = bundledManifestName
    }
}

public struct RewardVocabulary: Sendable, Equatable {
    public let singular: String
    public let plural: String
    public let celebration: String

    public init(singular: String, plural: String, celebration: String) {
        self.singular = singular
        self.plural = plural
        self.celebration = celebration
    }
}

public struct ProgressionRules: Sendable, Equatable {
    public let model: String
    public let pointsPerSuccess: Int
    public let unlockThresholds: [Int]

    public init(model: String, pointsPerSuccess: Int, unlockThresholds: [Int]) {
        self.model = model
        self.pointsPerSuccess = pointsPerSuccess
        self.unlockThresholds = unlockThresholds
    }
}

public struct FeatureFlags: Sendable, Equatable {
    private let values: [String: Bool]

    public init(_ values: [String: Bool]) { self.values = values }
    public subscript(_ key: String) -> Bool { values[key] ?? false }
    public var all: [String: Bool] { values }
}

public struct LearningAppConfiguration: Sendable, Equatable {
    public let identity: AppIdentity
    public let theme: ThemeTokens
    public let contentPack: ContentPackDescriptor
    public let locations: [LearningLocation]
    public let characters: [LearningCharacter]
    public let enabledSkills: [EducationalSkill]
    public let narration: NarrationSettings
    public let rewards: RewardVocabulary
    public let progression: ProgressionRules
    public let storageNamespace: String
    public let featureFlags: FeatureFlags

    public init(identity: AppIdentity, theme: ThemeTokens, contentPack: ContentPackDescriptor, locations: [LearningLocation], characters: [LearningCharacter], enabledSkills: [EducationalSkill], narration: NarrationSettings, rewards: RewardVocabulary, progression: ProgressionRules, storageNamespace: String, featureFlags: FeatureFlags) {
        precondition(!storageNamespace.isEmpty, "Each application needs a persistence namespace")
        self.identity = identity
        self.theme = theme
        self.contentPack = contentPack
        self.locations = locations
        self.characters = characters
        self.enabledSkills = enabledSkills
        self.narration = narration
        self.rewards = rewards
        self.progression = progression
        self.storageNamespace = storageNamespace
        self.featureFlags = featureFlags
    }
}

public struct LearningBehaviorHooks<State>: Sendable where State: Sendable {
    public let canOpenLocation: @Sendable (LearningLocation, State) -> Bool
    public let rewardLabel: @Sendable (Int) -> String

    public init(canOpenLocation: @escaping @Sendable (LearningLocation, State) -> Bool, rewardLabel: @escaping @Sendable (Int) -> String) {
        self.canOpenLocation = canOpenLocation
        self.rewardLabel = rewardLabel
    }
}
