import LearningEngine

struct CatStoryBeat: Identifiable, Hashable {
    let id: String
    let title: String
    /// One story page, a few sentences long. Each sentence is recorded and read aloud on its own.
    let sentences: [String]
    let puzzleLead: String

    var story: String { sentences.joined(separator: " ") }
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

    /// Puzzles in one round. A round is set in one story page and ends with a celebration.
    static let puzzlesPerRound = 3

    /// The story page a cat is on: a new page opens each time a round of puzzles is finished.
    func storyPage(for friendship: Int) -> Int {
        min(max(friendship, 0) / Self.puzzlesPerRound, backstory.count - 1)
    }

    func storyBeat(for friendship: Int) -> CatStoryBeat { backstory[storyPage(for: friendship)] }

    func revealedStory(for friendship: Int) -> [CatStoryBeat] {
        Array(backstory.prefix(storyPage(for: friendship) + 1))
    }

    /// Puzzles already solved in the round this friendship level is part of.
    func solvedInRound(for friendship: Int) -> Int { max(friendship, 0) % Self.puzzlesPerRound }

    /// The friendship level at which the last story page opens.
    var lastPageFriendship: Int { (backstory.count - 1) * Self.puzzlesPerRound }
}

enum CatContent {
    static let locations = [
        LearningLocation(id: "house", name: "House", symbol: "house.fill"),
        LearningLocation(id: "garden", name: "Garden", symbol: "leaf.fill")
    ]

    static let cats = [
        cat("mittens", "Mittens", "🐈", "#E07A5F", "house", "a red yarn ball", 0, "button", "buttons", "🔴", "the mitten flip", "🧤", [
            ("The tiny tailor", [
                "Mittens was found asleep in a basket of warm, hand-knit mittens.",
                "The mittens were soft and smelled like wool.",
                "She curled up so small that only her white paws showed.",
                "Now she naps beside the sewing basket every afternoon."
            ], "Beside the sewing basket,"),
            ("A helpful paw", [
                "She gathers every loose button so nobody steps on one.",
                "Buttons roll under chairs and hide in the rug.",
                "Mittens pats each one back to the button tin.",
                "She lines them up in neat little rows."
            ], "While tidying the button tin,"),
            ("Her red treasure", [
                "Her favorite yarn ball came from the very first mitten she helped mend.",
                "The yarn rolled away and left a long red trail.",
                "Mittens followed it around the table and under the bed.",
                "At the end she found her ball, safe and round."
            ], "Following the red yarn trail,"),
            ("A cozy dream", [
                "Mittens dreams of sewing a little patchwork blanket for every cat in the house.",
                "Each square will be a different color.",
                "She has saved bright buttons to sew on the corners.",
                "One day every cat will have a warm place to nap."
            ], "To finish the patchwork blanket,")
        ]),
        cat("pepper", "Pepper", "🐈‍⬛", "#5C677D", "house", "sunny windows", 0, "sunbeam", "sunbeams", "☀️", "the shadow pounce", "🌑", [
            ("The window watcher", [
                "Pepper arrived one rainy morning and chose the sunniest window as home.",
                "The glass was warm and the rain tapped outside.",
                "Pepper stretched out long in a patch of light.",
                "He has watched the world from that window ever since."
            ], "At Pepper’s sunny window,"),
            ("A weather expert", [
                "He can tell when rain is coming by the silvery smell in the air.",
                "He sniffs the breeze and looks up at the clouds.",
                "Gray clouds mean it is time to stay inside.",
                "Bright clouds mean the sunbeams are coming back."
            ], "While checking the weather,"),
            ("Secret kindness", [
                "Pepper leaves his warm window spot whenever another cat feels chilly.",
                "He scoots over without making a sound.",
                "Then he pretends he wanted the cool floor all along.",
                "A shared sunbeam feels twice as warm."
            ], "Sharing a warm sunbeam,"),
            ("His big plan", [
                "Pepper wants to map every patch of sunlight that travels across the house.",
                "In the morning the light lands on the kitchen floor.",
                "By lunch it has climbed onto the big blue chair.",
                "Pepper marks each sunny spot so no cat misses one."
            ], "Drawing the sunbeam map,")
        ]),
        cat("biscuit", "Biscuit", "🐱", "#F2CC8F", "house", "soft blankets", 0, "pillow", "pillows", "🟨", "the biscuit roll", "🌀", [
            ("The blanket burrower", [
                "Biscuit was discovered beneath a blanket with only two fuzzy ears showing.",
                "The blanket wiggled, then it purred.",
                "Out popped a sleepy cream-colored face.",
                "Biscuit has loved blanket forts ever since."
            ], "Inside the blanket fort,"),
            ("A gentle helper", [
                "She kneads lumpy pillows until they are perfectly soft for her friends.",
                "Push, push, push go her little paws.",
                "She tests each pillow with a slow, careful flop.",
                "When it is just right, she saves it for a friend."
            ], "Fluffing the pillows,"),
            ("Braver than she looks", [
                "Biscuit once crossed the noisy hallway to return a kitten’s lost toy.",
                "The hallway was long, and the vacuum was loud.",
                "Biscuit took a deep breath and tiptoed past.",
                "The kitten was so happy to see the toy again."
            ], "On a brave hallway trip,"),
            ("The coziest goal", [
                "She hopes to build the biggest, softest reading fort in the whole house.",
                "It needs tall pillow walls and a blanket roof.",
                "Inside there will be room for books and for friends.",
                "Biscuit is saving every soft pillow she can find."
            ], "Building the reading fort,")
        ]),
        cat("poppy", "Poppy", "😺", "#C77DFF", "house", "cardboard castles", 4, "cardboard tower", "cardboard towers", "🏰", "the royal wave", "👑", [
            ("Queen of boxes", [
                "Poppy moved into an empty delivery box and declared it her royal castle.",
                "She cut a window with her teeth and a door with her claws.",
                "A paper flag waves from the very top.",
                "Every visitor must bow before coming in."
            ], "Inside Poppy’s cardboard castle,"),
            ("A fair ruler", [
                "She gives every visiting cat an important job and a shiny paper crown.",
                "One cat guards the gate, and one cat rings the bell.",
                "Poppy folds each crown from shiny gold paper.",
                "No one is ever left without a crown."
            ], "Preparing paper crowns,"),
            ("The hidden passage", [
                "A tunnel behind her throne leads all the way to the kitchen.",
                "It is dark inside, but Poppy is not afraid.",
                "She counts her steps so she never gets lost.",
                "At the end there is always a snack waiting."
            ], "Exploring the secret tunnel,"),
            ("A grand design", [
                "Poppy plans a cardboard village where every cat gets a castle.",
                "She draws the plan on the side of a big box.",
                "There will be towers, bridges, and a tall front gate.",
                "The more boxes that arrive, the bigger the village grows."
            ], "Planning the cardboard village,")
        ]),
        cat("waffles", "Waffles", "😸", "#F4A261", "house", "breakfast time", 9, "berry", "berries", "🫐", "the breakfast boogie", "🥞", [
            ("The breakfast bell", [
                "Waffles appears each morning exactly when the toaster pops.",
                "Pop goes the toaster, and in trots Waffles.",
                "He sits up tall on his chair at the table.",
                "He has never been late for breakfast, not even once."
            ], "At the breakfast table,"),
            ("A careful collector", [
                "He saves fallen berries in a tiny bowl instead of letting them roll away.",
                "Blueberries are round, so they roll very fast.",
                "Waffles traps each one gently under his paw.",
                "Then he drops it into the bowl with a soft plop."
            ], "Filling the berry bowl,"),
            ("His early adventure", [
                "Before everyone wakes, Waffles patrols the quiet house for misplaced slippers.",
                "The house is dark and still before the sun comes up.",
                "One slipper hides under the sofa, and one sits by the door.",
                "Waffles carries each slipper back to its bed."
            ], "On the morning slipper patrol,"),
            ("A delicious dream", [
                "Waffles wants to host a pancake picnic for every friend he has made.",
                "He will need a big blanket and a tall stack of pancakes.",
                "Every friend will get berries on top.",
                "Waffles is already counting how many plates to set out."
            ], "Preparing the pancake picnic,")
        ]),
        cat("clover", "Clover", "🐈", "#76C893", "garden", "butterflies", 0, "butterfly", "butterflies", "🦋", "the butterfly bow", "🍀", [
            ("The garden greeter", [
                "Clover first appeared beneath a lucky patch of four-leaf clovers.",
                "The leaves were green and cool with morning dew.",
                "She says hello to every bee, bird, and beetle.",
                "The garden feels friendlier with Clover in it."
            ], "Among the clover leaves,"),
            ("A patient friend", [
                "She sits very still so tired butterflies can rest beside her.",
                "One lands on a flower, and one lands on her ear.",
                "Clover does not even twitch her tail.",
                "When they are rested, they flutter away again."
            ], "Welcoming the butterflies,"),
            ("The garden guide", [
                "Clover knows a quiet path that winds past every flower bed.",
                "It curves around the roses and under the apple tree.",
                "She walks slowly so that small friends can keep up.",
                "Nobody gets lost when Clover leads the way."
            ], "Along the secret garden path,"),
            ("Her hopeful project", [
                "She is growing a butterfly garden filled with safe places to land.",
                "She picks flowers that butterflies love best.",
                "Purple ones go in the front, and yellow ones go in the back.",
                "Each new flower brings a new butterfly."
            ], "Growing the butterfly garden,")
        ]),
        cat("moon", "Moon", "🐈‍⬛", "#7986CB", "garden", "evening breezes", 0, "star", "stars", "⭐", "the moonwalk", "🌙", [
            ("The evening explorer", [
                "Moon visits the garden when the first evening star begins to glow.",
                "The sky turns purple, and the air grows cool.",
                "Moon pads softly along the top of the garden wall.",
                "She likes to watch the stars come out, one by one."
            ], "Under the evening sky,"),
            ("A quiet listener", [
                "She recognizes each friend by the sound of their footsteps after dark.",
                "Quick little steps mean Sprout is coming.",
                "Big bouncy steps mean Ginger is on his way.",
                "Moon always knows who is there before they say hello."
            ], "Listening in the moonlit garden,"),
            ("The lantern keeper", [
                "Moon guides sleepy fireflies back to their favorite leaves.",
                "Their tiny lights blink slower when they are tired.",
                "Moon walks ahead and shows them the way.",
                "Soon each firefly is tucked in for the night."
            ], "Guiding the fireflies home,"),
            ("Her night-sky wish", [
                "She hopes to name every star that can be seen from the garden wall.",
                "Some stars are bright, and some are very small.",
                "She gives each one a name she can remember.",
                "There are so many stars that it may take all summer."
            ], "Making Moon’s star map,")
        ]),
        cat("ginger", "Ginger", "😻", "#E76F51", "garden", "warm stepping stones", 6, "stepping stone", "stepping stones", "🟠", "the ginger leap", "✨", [
            ("The sunny-stone cat", [
                "Ginger followed a trail of warm stepping stones into the garden.",
                "Each stone was warmer than the one before.",
                "He hopped from one to the next without touching the grass.",
                "The last stone was the warmest, so that is where he stayed."
            ], "On the sunny stepping stones,"),
            ("A bold jumper", [
                "He can cross the little stream without getting one paw wet.",
                "He wiggles, he crouches, and then he springs.",
                "For a moment he looks like he is flying.",
                "He lands on the far side with a proud little flick of his tail."
            ], "Leaping across the stream,"),
            ("A hidden soft side", [
                "Ginger warms cold stones for smaller cats before they arrive.",
                "He lies on each cold stone until it is toasty.",
                "Then he moves along to warm the next one.",
                "He never tells anyone, but his friends always know."
            ], "Warming stones for friends,"),
            ("His greatest course", [
                "He dreams of building a garden obstacle course for every skill level.",
                "There will be low hops for kittens and long leaps for big cats.",
                "A tunnel, a bridge, and a wobbly log come next.",
                "Everyone gets a cheer at the finish line."
            ], "Designing the obstacle course,")
        ]),
        cat("sprout", "Sprout", "😽", "#52B788", "garden", "tiny seedlings", 12, "seedling", "seedlings", "🌱", "the sprout stretch", "🌿", [
            ("The seedling guardian", [
                "Sprout was curled around a tiny seedling during a windy spring day.",
                "The wind blew hard, but the little plant stayed safe.",
                "Sprout kept it warm until the sun came out.",
                "Now she checks on every seedling each morning."
            ], "Beside the seedling pots,"),
            ("A muddy secret", [
                "She does not mind muddy paws when a thirsty plant needs help.",
                "She tips the watering can with her nose.",
                "Splash goes the water, and squish goes the mud.",
                "The plants stand up tall after a good long drink."
            ], "Watering the seedlings,"),
            ("Her growing gift", [
                "Sprout remembers exactly which song helps each flower grow.",
                "The daisies like a soft and sleepy hum.",
                "The sunflowers like a loud and happy tune.",
                "Sprout sings to each one until its leaves reach up."
            ], "Singing the growing song,"),
            ("A garden promise", [
                "She plans to grow a shady green tunnel for cats to explore.",
                "First she must plant two long rows of climbing vines.",
                "They will grow up and over until they meet at the top.",
                "Inside it will be cool, green, and full of whispers."
            ], "Planning the green tunnel,")
        ]),
        cat("starlight", "Starlight", "😺", "#9D4EDD", "garden", "fireflies", 18, "firefly", "fireflies", "🌟", "the starlight spin", "💫", [
            ("The firefly friend", [
                "Starlight arrived on a summer night surrounded by twinkling fireflies.",
                "Their lights danced all around her silver fur.",
                "She sat very still and watched them glow.",
                "Ever since, the fireflies have followed wherever she goes."
            ], "In the firefly meadow,"),
            ("A maker of patterns", [
                "She watches the flashes and finds secret repeating patterns in their light.",
                "Blink, blink, pause. Blink, blink, pause.",
                "She taps her paw along with each flash.",
                "Once she knows the pattern, she can guess what comes next."
            ], "Following the flashing pattern,"),
            ("A guiding glow", [
                "Starlight helps late garden visitors find the path back home.",
                "The fireflies gather close around her tail.",
                "Together they shine like a small walking lantern.",
                "No one has to walk home in the dark."
            ], "Lighting the garden path,"),
            ("Her sparkling celebration", [
                "She wants to choreograph a firefly dance for all ten cat friends.",
                "The fireflies will spin in circles and swoop in lines.",
                "Each cat will have a special spot to stand in.",
                "It will be the brightest night the garden has ever seen."
            ], "Planning the firefly dance,")
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
        _ beats: [(String, [String], String)]
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
                CatStoryBeat(id: "\(id)-\(index)", title: beat.0, sentences: beat.1, puzzleLead: beat.2)
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
