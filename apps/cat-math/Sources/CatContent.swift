import LearningEngine

struct CatDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let color: String
    let locationID: String
    let favoriteThing: String
    let unlockAt: Int
}

enum CatContent {
    static let locations = [
        LearningLocation(id: "house", name: "House", symbol: "house.fill"),
        LearningLocation(id: "garden", name: "Garden", symbol: "leaf.fill")
    ]

    static let cats = [
        CatDefinition(id: "mittens", name: "Mittens", symbol: "🐈", color: "#E07A5F", locationID: "house", favoriteThing: "a red yarn ball", unlockAt: 0),
        CatDefinition(id: "pepper", name: "Pepper", symbol: "🐈‍⬛", color: "#5C677D", locationID: "house", favoriteThing: "sunny windows", unlockAt: 0),
        CatDefinition(id: "biscuit", name: "Biscuit", symbol: "🐱", color: "#F2CC8F", locationID: "house", favoriteThing: "soft blankets", unlockAt: 0),
        CatDefinition(id: "poppy", name: "Poppy", symbol: "😺", color: "#C77DFF", locationID: "house", favoriteThing: "cardboard castles", unlockAt: 4),
        CatDefinition(id: "waffles", name: "Waffles", symbol: "😸", color: "#F4A261", locationID: "house", favoriteThing: "breakfast time", unlockAt: 9),
        CatDefinition(id: "clover", name: "Clover", symbol: "🐈", color: "#76C893", locationID: "garden", favoriteThing: "butterflies", unlockAt: 0),
        CatDefinition(id: "moon", name: "Moon", symbol: "🐈‍⬛", color: "#7986CB", locationID: "garden", favoriteThing: "evening breezes", unlockAt: 0),
        CatDefinition(id: "ginger", name: "Ginger", symbol: "😻", color: "#E76F51", locationID: "garden", favoriteThing: "warm stepping stones", unlockAt: 6),
        CatDefinition(id: "sprout", name: "Sprout", symbol: "😽", color: "#52B788", locationID: "garden", favoriteThing: "tiny seedlings", unlockAt: 12),
        CatDefinition(id: "starlight", name: "Starlight", symbol: "😺", color: "#9D4EDD", locationID: "garden", favoriteThing: "fireflies", unlockAt: 18)
    ]

    static let skills = [
        EducationalSkill(id: "counting", displayName: "Counting"),
        EducationalSkill(id: "addition", displayName: "Addition"),
        EducationalSkill(id: "subtraction", displayName: "Subtraction"),
        EducationalSkill(id: "odd-even", displayName: "Odd and even"),
        EducationalSkill(id: "skip-5", displayName: "Skip counting by 5"),
        EducationalSkill(id: "skip-10", displayName: "Skip counting by 10")
    ]
}

enum CatAppConfiguration {
    static let value = LearningAppConfiguration(
        identity: AppIdentity(applicationIdentifier: "com.mkilgore.CatMathAdventure", displayName: "Cat Math Adventure", childFacingName: "Kate’s Cat Math Adventure", iconAssetName: "CatAppIcon", splashAssetName: "CatSplash"),
        theme: ThemeTokens(background: ["#FFF4D6", "#FADADD", "#CDECEF"], primary: "#A855F7", secondary: "#F97316", success: "#22C55E", surface: "#FFF9EE"),
        contentPack: ContentPackDescriptor(id: "kate-cat-math", version: 1, resourceName: "cat-catalog"),
        locations: CatContent.locations,
        characters: CatContent.cats.map { LearningCharacter(id: $0.id, name: $0.name, locationID: $0.locationID) },
        enabledSkills: CatContent.skills,
        narration: NarrationSettings(language: "en-US", normalRate: 0.46, slowRate: 0.36, pitch: 1.08),
        rewards: RewardVocabulary(singular: "friendship heart", plural: "friendship hearts", celebration: "Your friendship grew!"),
        progression: ProgressionRules(model: "friendship", pointsPerSuccess: 1, unlockThresholds: [0, 4, 6, 9, 12, 18]),
        storageNamespace: "com.mkilgore.CatMathAdventure.kate",
        featureFlags: FeatureFlags(["journal": true, "visualHints": true, "narratedPrompts": true])
    )
}
