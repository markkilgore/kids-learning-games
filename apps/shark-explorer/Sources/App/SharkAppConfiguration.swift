import LearningEngine

enum SharkAppConfiguration {
    static let value = LearningAppConfiguration(
        identity: AppIdentity(
            applicationIdentifier: "com.mkilgore.SharkExplorer",
            displayName: "Shark Explorer",
            childFacingName: "Henry’s Shark Explorer",
            iconAssetName: "AppIcon",
            splashAssetName: "SharkSplash"
        ),
        theme: ThemeTokens(
            background: ["#041E42", "#006D8F", "#00A6A6"],
            primary: "#2AB7CA",
            secondary: "#F4A261",
            success: "#4CAF50",
            surface: "#0A4260"
        ),
        contentPack: ContentPackDescriptor(id: "henry-sharks", version: 1, resourceName: "catalog"),
        locations: [LearningLocation(id: "ocean-map", name: "Ocean Map", symbol: "map.fill")],
        characters: [
            ("whale", "Whale Shark"), ("hammerhead", "Hammerhead Shark"), ("nurse", "Nurse Shark"),
            ("great-white", "Great White Shark"), ("wobbegong", "Wobbegong"), ("thresher", "Thresher Shark"),
            ("tiger", "Tiger Shark"), ("epaulette", "Epaulette Shark"), ("goblin", "Goblin Shark"),
            ("greenland", "Greenland Shark")
        ].map { LearningCharacter(id: $0.0, name: $0.1, locationID: "ocean-map") },
        enabledSkills: [
            EducationalSkill(id: "reading", displayName: "Guided reading"),
            EducationalSkill(id: "science", displayName: "Shark science"),
            EducationalSkill(id: "vocabulary", displayName: "Ocean vocabulary")
        ],
        narration: NarrationSettings(bundledManifestName: "audio-manifest"),
        rewards: RewardVocabulary(singular: "shark page", plural: "shark pages", celebration: "Ocean word collected!"),
        progression: ProgressionRules(model: "guided-unlocks", pointsPerSuccess: 1, unlockThresholds: [0, 1, 3, 6]),
        storageNamespace: "com.mkilgore.SharkExplorer.henry",
        featureFlags: FeatureFlags(["books": true, "parentSettings": true, "pictureQuestions": true])
    )
}
