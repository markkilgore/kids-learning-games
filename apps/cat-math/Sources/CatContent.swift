import LearningEngine

struct CatStoryBeat: Identifiable, Hashable {
    let id: String
    let title: String
    let story: String
    let puzzleLead: String
}

struct CatDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let color: String
    let locationID: String
    let favoriteThing: String
    let unlockAt: Int
    let storyItem: String
    let storyItemPlural: String
    let storyIcon: String
    let trickName: String
    let trickSymbol: String
    let backstory: [CatStoryBeat]

    func storyBeat(for friendship: Int) -> CatStoryBeat {
        backstory[min(max(friendship, 0), backstory.count - 1)]
    }

    func revealedStory(for friendship: Int) -> [CatStoryBeat] {
        Array(backstory.prefix(min(max(friendship, 0) + 1, backstory.count)))
    }
}

enum CatContent {
    static let locations = [
        LearningLocation(id: "house", name: "House", symbol: "house.fill"),
        LearningLocation(id: "garden", name: "Garden", symbol: "leaf.fill")
    ]

    static let cats = [
        cat("mittens", "Mittens", "🐈", "#E07A5F", "house", "a red yarn ball", 0, "button", "buttons", "🔴", "the mitten flip", "🧤", [
            ("The tiny tailor", "Mittens was found asleep in a basket of warm, hand-knit mittens.", "Beside the sewing basket,"),
            ("A helpful paw", "She gathers every loose button so nobody steps on one.", "While tidying the button tin,"),
            ("Her red treasure", "Her favorite yarn ball came from the very first mitten she helped mend.", "Following the red yarn trail,"),
            ("A cozy dream", "Mittens dreams of sewing a little patchwork blanket for every cat in the house.", "To finish the patchwork blanket,")
        ]),
        cat("pepper", "Pepper", "🐈‍⬛", "#5C677D", "house", "sunny windows", 0, "sunbeam", "sunbeams", "☀️", "the shadow pounce", "🌑", [
            ("The window watcher", "Pepper arrived one rainy morning and chose the sunniest window as home.", "At Pepper’s sunny window,"),
            ("A weather expert", "He can tell when rain is coming by the silvery smell in the air.", "While checking the weather,"),
            ("Secret kindness", "Pepper leaves his warm window spot whenever another cat feels chilly.", "Sharing a warm sunbeam,"),
            ("His big plan", "Pepper wants to map every patch of sunlight that travels across the house.", "Drawing the sunbeam map,")
        ]),
        cat("biscuit", "Biscuit", "🐱", "#F2CC8F", "house", "soft blankets", 0, "pillow", "pillows", "🟨", "the biscuit roll", "🌀", [
            ("The blanket burrower", "Biscuit was discovered beneath a blanket with only two fuzzy ears showing.", "Inside the blanket fort,"),
            ("A gentle helper", "She kneads lumpy pillows until they are perfectly soft for her friends.", "Fluffing the pillows,"),
            ("Braver than she looks", "Biscuit once crossed the noisy hallway to return a kitten’s lost toy.", "On a brave hallway trip,"),
            ("The coziest goal", "She hopes to build the biggest, softest reading fort in the whole house.", "Building the reading fort,")
        ]),
        cat("poppy", "Poppy", "😺", "#C77DFF", "house", "cardboard castles", 4, "cardboard tower", "cardboard towers", "🏰", "the royal wave", "👑", [
            ("Queen of boxes", "Poppy moved into an empty delivery box and declared it her royal castle.", "Inside Poppy’s cardboard castle,"),
            ("A fair ruler", "She gives every visiting cat an important job and a shiny paper crown.", "Preparing paper crowns,"),
            ("The hidden passage", "A tunnel behind her throne leads all the way to the kitchen.", "Exploring the secret tunnel,"),
            ("A grand design", "Poppy plans a cardboard village where every cat gets a castle.", "Planning the cardboard village,")
        ]),
        cat("waffles", "Waffles", "😸", "#F4A261", "house", "breakfast time", 9, "berry", "berries", "🫐", "the breakfast boogie", "🥞", [
            ("The breakfast bell", "Waffles appears each morning exactly when the toaster pops.", "At the breakfast table,"),
            ("A careful collector", "He saves fallen berries in a tiny bowl instead of letting them roll away.", "Filling the berry bowl,"),
            ("His early adventure", "Before everyone wakes, Waffles patrols the quiet house for misplaced slippers.", "On the morning slipper patrol,"),
            ("A delicious dream", "Waffles wants to host a pancake picnic for every friend he has made.", "Preparing the pancake picnic,")
        ]),
        cat("clover", "Clover", "🐈", "#76C893", "garden", "butterflies", 0, "butterfly", "butterflies", "🦋", "the butterfly bow", "🍀", [
            ("The garden greeter", "Clover first appeared beneath a lucky patch of four-leaf clovers.", "Among the clover leaves,"),
            ("A patient friend", "She sits very still so tired butterflies can rest beside her.", "Welcoming the butterflies,"),
            ("The garden guide", "Clover knows a quiet path that winds past every flower bed.", "Along the secret garden path,"),
            ("Her hopeful project", "She is growing a butterfly garden filled with safe places to land.", "Growing the butterfly garden,")
        ]),
        cat("moon", "Moon", "🐈‍⬛", "#7986CB", "garden", "evening breezes", 0, "star", "stars", "⭐", "the moonwalk", "🌙", [
            ("The evening explorer", "Moon visits the garden when the first evening star begins to glow.", "Under the evening sky,"),
            ("A quiet listener", "She recognizes each friend by the sound of their footsteps after dark.", "Listening in the moonlit garden,"),
            ("The lantern keeper", "Moon guides sleepy fireflies back to their favorite leaves.", "Guiding the fireflies home,"),
            ("Her night-sky wish", "She hopes to name every star that can be seen from the garden wall.", "Making Moon’s star map,")
        ]),
        cat("ginger", "Ginger", "😻", "#E76F51", "garden", "warm stepping stones", 6, "stepping stone", "stepping stones", "🟠", "the ginger leap", "✨", [
            ("The sunny-stone cat", "Ginger followed a trail of warm stepping stones into the garden.", "On the sunny stepping stones,"),
            ("A bold jumper", "He can cross the little stream without getting one paw wet.", "Leaping across the stream,"),
            ("A hidden soft side", "Ginger warms cold stones for smaller cats before they arrive.", "Warming stones for friends,"),
            ("His greatest course", "He dreams of building a garden obstacle course for every skill level.", "Designing the obstacle course,")
        ]),
        cat("sprout", "Sprout", "😽", "#52B788", "garden", "tiny seedlings", 12, "seedling", "seedlings", "🌱", "the sprout stretch", "🌿", [
            ("The seedling guardian", "Sprout was curled around a tiny seedling during a windy spring day.", "Beside the seedling pots,"),
            ("A muddy secret", "She does not mind muddy paws when a thirsty plant needs help.", "Watering the seedlings,"),
            ("Her growing gift", "Sprout remembers exactly which song helps each flower grow.", "Singing the growing song,"),
            ("A garden promise", "She plans to grow a shady green tunnel for cats to explore.", "Planning the green tunnel,")
        ]),
        cat("starlight", "Starlight", "😺", "#9D4EDD", "garden", "fireflies", 18, "firefly", "fireflies", "🌟", "the starlight spin", "💫", [
            ("The firefly friend", "Starlight arrived on a summer night surrounded by twinkling fireflies.", "In the firefly meadow,"),
            ("A maker of patterns", "She watches the flashes and finds secret repeating patterns in their light.", "Following the flashing pattern,"),
            ("A guiding glow", "Starlight helps late garden visitors find the path back home.", "Lighting the garden path,"),
            ("Her sparkling celebration", "She wants to choreograph a firefly dance for all ten cat friends.", "Planning the firefly dance,")
        ])
    ]

    static let skills = [
        EducationalSkill(id: "counting", displayName: "Counting"),
        EducationalSkill(id: "addition", displayName: "Addition"),
        EducationalSkill(id: "subtraction", displayName: "Subtraction"),
        EducationalSkill(id: "odd-even", displayName: "Odd and even"),
        EducationalSkill(id: "skip-5", displayName: "Skip counting by 5"),
        EducationalSkill(id: "skip-10", displayName: "Skip counting by 10")
    ]

    private static func cat(
        _ id: String,
        _ name: String,
        _ symbol: String,
        _ color: String,
        _ locationID: String,
        _ favoriteThing: String,
        _ unlockAt: Int,
        _ storyItem: String,
        _ storyItemPlural: String,
        _ storyIcon: String,
        _ trickName: String,
        _ trickSymbol: String,
        _ beats: [(String, String, String)]
    ) -> CatDefinition {
        CatDefinition(
            id: id,
            name: name,
            symbol: symbol,
            color: color,
            locationID: locationID,
            favoriteThing: favoriteThing,
            unlockAt: unlockAt,
            storyItem: storyItem,
            storyItemPlural: storyItemPlural,
            storyIcon: storyIcon,
            trickName: trickName,
            trickSymbol: trickSymbol,
            backstory: beats.enumerated().map { index, beat in
                CatStoryBeat(id: "\(id)-\(index)", title: beat.0, story: beat.1, puzzleLead: beat.2)
            }
        )
    }
}

enum CatAppConfiguration {
    static let value = LearningAppConfiguration(
        identity: AppIdentity(applicationIdentifier: "com.mkilgore.CatMathAdventure", displayName: "Cat Math Adventure", childFacingName: "Kate’s Cat Math Adventure", iconAssetName: "CatAppIcon", splashAssetName: "CatSplash"),
        theme: ThemeTokens(background: ["#FFF4D6", "#FADADD", "#CDECEF"], primary: "#A855F7", secondary: "#F97316", success: "#22C55E", surface: "#FFF9EE"),
        contentPack: ContentPackDescriptor(id: "kate-cat-math", version: 1, resourceName: "cat-catalog"),
        locations: CatContent.locations,
        characters: CatContent.cats.map { LearningCharacter(id: $0.id, name: $0.name, locationID: $0.locationID) },
        enabledSkills: CatContent.skills,
        narration: NarrationSettings(language: "en-US", normalRate: 0.46, slowRate: 0.36, pitch: 1.08, bundledManifestName: "cat-audio-manifest"),
        rewards: RewardVocabulary(singular: "friendship heart", plural: "friendship hearts", celebration: "Your friendship grew!"),
        progression: ProgressionRules(model: "friendship", pointsPerSuccess: 1, unlockThresholds: [0, 4, 6, 9, 12, 18]),
        storageNamespace: "com.mkilgore.CatMathAdventure.kate",
        featureFlags: FeatureFlags(["journal": true, "visualHints": true, "narratedPrompts": true])
    )
}
