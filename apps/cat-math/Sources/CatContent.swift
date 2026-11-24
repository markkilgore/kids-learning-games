import LearningEngine

struct CatStoryBeat: Identifiable, Hashable {
    let id: String
    let title: String
    /// The school reading unit this page practises; see `ReadingFocus` and cat-reading.json.
    let focusID: String
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
            ("The tiny tailor", "sh", [
                "Mittens was found asleep in a basket of warm, hand-knit mittens.",
                "The mittens were soft, and some had shiny shell buttons.",
                "She curled up by a shelf, and only her white paws showed.",
                "You would know her by her soft, sleepy purr, if you could hear it."
            ], "Beside the sewing basket,"),
            ("A helpful paw", "th-wh", [
                "She gathers every loose button so nobody steps on one.",
                "Buttons jump off the table and roll under their chairs.",
                "Mittens knows where each one hides, and that is why she finds them.",
                "With three soft pats, she can walk them right back to the tin."
            ], "While tidying the button tin,"),
            ("Her red treasure", "ch", [
                "Her favorite yarn ball came from the very first mitten she helped mend.",
                "Today it rolled off a chair and started a long red trail.",
                "Mittens chased it past the kitchen and under a bench.",
                "Here it is, safe by the couch, and now she can play."
            ], "Following the red yarn trail,"),
            ("A cozy dream", "s-blends", [
                "Mittens dreams of sewing a little patchwork blanket for every cat in the house.",
                "She does not stop before each small square is snug.",
                "After the last stitch, she smooths the blankets into a soft stack.",
                "No cat will sleep cold, and the stack will grow."
            ], "To finish the patchwork blanket,")
        ]),
        cat("pepper", "Pepper", "🐈‍⬛", "#5C677D", "house", "sunny windows", 0, "sunbeam", "sunbeams", "☀️", "the shadow pounce", "🌑", [
            ("The window watcher", "th-wh", [
                "Pepper arrived one rainy morning and chose the sunniest window as home.",
                "He likes the way the warm sun feels on his whiskers.",
                "From there he can see where the birds walk and jump.",
                "That is why he thinks this is the right spot for a nap."
            ], "At Pepper’s sunny window,"),
            ("A weather expert", "ch", [
                "He can tell when rain is coming by the silvery smell in the air.",
                "Today he sat on his chair to check the sky.",
                "A chilly wind started to push the clouds along.",
                "Pepper knew it would be very wet, so the cats chose to play in here."
            ], "While checking the weather,"),
            ("Secret kindness", "s-blends", [
                "Pepper leaves his warm window spot whenever another cat feels chilly.",
                "He does not say a word before he slips away.",
                "A small cat can step into the sunbeam and stretch.",
                "After a while, no one is cold, and Pepper smiles."
            ], "Sharing a warm sunbeam,"),
            ("His big plan", "l-blends", [
                "Pepper wants to map every patch of sunlight that travels across the house.",
                "He found a bright glow on the floor by the plants.",
                "By lunch it had come around to the big blue chair.",
                "Two other cats came to help, and they worked on the plan all day."
            ], "Drawing the sunbeam map,")
        ]),
        cat("biscuit", "Biscuit", "🐱", "#F2CC8F", "house", "soft blankets", 0, "pillow", "pillows", "🟨", "the biscuit roll", "🌀", [
            ("The blanket burrower", "ch", [
                "Biscuit was discovered beneath a blanket with only two fuzzy ears showing.",
                "The blanket on the big chair started to wiggle.",
                "Out popped a cheerful face with a furry chin.",
                "Today that chair is her very best place to play."
            ], "Inside the blanket fort,"),
            ("A gentle helper", "s-blends", [
                "She kneads lumpy pillows until they are perfectly soft for her friends.",
                "Before nap time, she steps onto each pillow.",
                "She does a slow spin and a small stomp.",
                "After that, no lumps are left, and she can wash her paws."
            ], "Fluffing the pillows,"),
            ("Braver than she looks", "l-blends", [
                "Biscuit once crossed the noisy hallway to return a kitten’s lost toy.",
                "She found the toy clown under a blue blanket.",
                "The other cats were too scared to come past the loud clock.",
                "Biscuit came around the corner with a glad little flick of her tail."
            ], "On a brave hallway trip,"),
            ("The coziest goal", "sh", [
                "She hopes to build the biggest, softest reading fort in the whole house.",
                "There would be a sheet for the roof and cushions by the door.",
                "Some shelves could hold books for her friends to share.",
                "She does not know when it will be finished, but she will not rush."
            ], "Building the reading fort,")
        ]),
        cat("poppy", "Poppy", "😺", "#C77DFF", "house", "cardboard castles", 4, "cardboard tower", "cardboard towers", "🏰", "the royal wave", "👑", [
            ("Queen of boxes", "s-blends", [
                "Poppy moved into an empty delivery box and declared it her royal castle.",
                "Before lunch, she made a small window and a strong door.",
                "A flag on a stick stands at the very top.",
                "Don’t step inside until she does a royal spin."
            ], "Inside Poppy’s cardboard castle,"),
            ("A fair ruler", "l-blends", [
                "She gives every visiting cat an important job and a shiny paper crown.",
                "Two cats came to clean the flag and guard the gate.",
                "The other cats worked to glue blue gems on each crown.",
                "When people come around, Poppy claps for her helpers."
            ], "Preparing paper crowns,"),
            ("The hidden passage", "sh", [
                "A tunnel behind her throne leads all the way to the kitchen.",
                "There were shadows inside, but she could see a shine at the end.",
                "She would push by some old boxes and shuffle along.",
                "You know what she found there? A dish of fish."
            ], "Exploring the secret tunnel,"),
            ("A grand design", "th-wh", [
                "Poppy plans a cardboard village where every cat gets a castle.",
                "She thinks about where their paths and bridges should go.",
                "Then she draws a white wheel to show which way to walk.",
                "Why stop at three castles when there are boxes for thirty?"
            ], "Planning the cardboard village,")
        ]),
        cat("waffles", "Waffles", "😸", "#F4A261", "house", "breakfast time", 9, "berry", "berries", "🫐", "the breakfast boogie", "🥞", [
            ("The breakfast bell", "l-blends", [
                "Waffles appears each morning exactly when the toaster pops.",
                "He came to his place and found a clean blue plate.",
                "Two other cats come in slowly, still blinking.",
                "When the people sit down, Waffles is glad he worked so hard to be first."
            ], "At the breakfast table,"),
            ("A careful collector", "sh", [
                "He saves fallen berries in a tiny bowl instead of letting them roll away.",
                "Some berries were by the dish, and some were under a shoe.",
                "He could push each one with a gentle swish.",
                "You would not know there had been a spill when he was finished."
            ], "Filling the berry bowl,"),
            ("His early adventure", "th-wh", [
                "Before everyone wakes, Waffles patrols the quiet house for misplaced slippers.",
                "He knows where to walk and which way to look.",
                "One slipper is beneath the bath mat, and another is with the white socks.",
                "Why do they hide? Waffles cannot say, but he puts them right back."
            ], "On the morning slipper patrol,"),
            ("A delicious dream", "ch", [
                "Waffles wants to host a pancake picnic for every friend he has made.",
                "Today he started to choose the best spot for lunch.",
                "He will use a big chair for the cheese and cherries.",
                "‘Come here and play with me,’ he will say, and it will be a very happy day."
            ], "Preparing the pancake picnic,")
        ]),
        cat("clover", "Clover", "🐈", "#76C893", "garden", "butterflies", 0, "butterfly", "butterflies", "🦋", "the butterfly bow", "🍀", [
            ("The garden greeter", "s-blends", [
                "Clover first appeared beneath a lucky patch of four-leaf clovers.",
                "Before the sun is up, she steps into the soft, sweet grass.",
                "She stops to greet a snail, a spider, and a small bee.",
                "No friend is left out, and after that the smiles grow."
            ], "Among the clover leaves,"),
            ("A patient friend", "th-wh", [
                "She sits very still so tired butterflies can rest beside her.",
                "They know the way to her and where it is safe to land.",
                "One sits on her white whiskers, and another on her thick fur.",
                "That is why she does not jump or walk, and their wings can rest."
            ], "Welcoming the butterflies,"),
            ("The garden guide", "ch", [
                "Clover knows a quiet path that winds past every flower bed.",
                "Today she started at the bench by the cherry tree.",
                "‘Come with me, each step is safe here,’ she chirps.",
                "It is very much fun to play on a path she chose."
            ], "Along the secret garden path,"),
            ("Her hopeful project", "sh", [
                "She is growing a butterfly garden filled with safe places to land.",
                "There would be fresh flowers by a shady bush.",
                "Some butterflies were shy, so she made a place to shelter.",
                "She could call them in with a soft shush, and they know they are safe."
            ], "Growing the butterfly garden,")
        ]),
        cat("moon", "Moon", "🐈‍⬛", "#7986CB", "garden", "evening breezes", 0, "star", "stars", "⭐", "the moonwalk", "🌙", [
            ("The evening explorer", "l-blends", [
                "Moon visits the garden when the first evening star begins to glow.",
                "She came around the wall on her black, silent paws.",
                "She found a flat place to sit, close to the plum tree.",
                "Two stars blink, then other stars come out to play."
            ], "Under the evening sky,"),
            ("A quiet listener", "ch", [
                "She recognizes each friend by the sound of their footsteps after dark.",
                "A quick scratch on the porch tells her Sprout is here.",
                "A crunch on the branch means Ginger started to play.",
                "Today the garden is very quiet, so Moon can be still and watch."
            ], "Listening in the moonlit garden,"),
            ("The lantern keeper", "s-blends", [
                "Moon guides sleepy fireflies back to their favorite leaves.",
                "Before they stop for the night, their small lights grow slow.",
                "Moon steps into the grass and shows them the way.",
                "After that, no firefly is lost, and the stars spark above."
            ], "Guiding the fireflies home,"),
            ("Her night-sky wish", "th-wh", [
                "She hopes to name every star that can be seen from the garden wall.",
                "She knows where the white ones are and which are thin and far.",
                "Three sit right above the path, and their light shows the way to walk.",
                "Why are there so many? She cannot say, but she thanks them all the same."
            ], "Making Moon’s star map,")
        ]),
        cat("ginger", "Ginger", "😻", "#E76F51", "garden", "warm stepping stones", 6, "stepping stone", "stepping stones", "🟠", "the ginger leap", "✨", [
            ("The sunny-stone cat", "ch", [
                "Ginger followed a trail of warm stepping stones into the garden.",
                "Today he started with a stone by the bench.",
                "Each one was a touch warmer, so he chose the next, and the next.",
                "The last stone was the very best, so here he will be, chin on his paws."
            ], "On the sunny stepping stones,"),
            ("A bold jumper", "s-blends", [
                "He can cross the little stream without getting one paw wet.",
                "Before he springs, he stops and stands very still.",
                "He does a small wiggle and sails into the air.",
                "After he lands, no splash can be seen, only a smile."
            ], "Leaping across the stream,"),
            ("A hidden soft side", "l-blends", [
                "Ginger warms cold stones for smaller cats before they arrive.",
                "He found two flat stones that were too cold to sit on.",
                "He plopped down and stayed until they were close to glowing.",
                "Then the other cats came around, glad for a warm place to sleep."
            ], "Warming stones for friends,"),
            ("His greatest course", "sh", [
                "He dreams of building a garden obstacle course for every skill level.",
                "There would be a short hop for kittens and a dash by the shed.",
                "Some cats could shoot ahead, and some could shuffle along.",
                "They would all know they had done well when they heard a shout at the finish."
            ], "Designing the obstacle course,")
        ]),
        cat("sprout", "Sprout", "😽", "#52B788", "garden", "tiny seedlings", 12, "seedling", "seedlings", "🌱", "the sprout stretch", "🌿", [
            ("The seedling guardian", "s-blends", [
                "Sprout was curled around a tiny seedling during a windy spring day.",
                "Before the storm, the small stem had started to slip.",
                "Sprout stayed close, so no wind could snap it.",
                "After the sun came out, it began to grow straight and strong."
            ], "Beside the seedling pots,"),
            ("A muddy secret", "l-blends", [
                "She does not mind muddy paws when a thirsty plant needs help.",
                "She found two clay pots with floppy leaves.",
                "She came around with a splash and a plop, glad to help.",
                "The other plants stood up tall, and the flowers looked clean and bright."
            ], "Watering the seedlings,"),
            ("Her growing gift", "sh", [
                "Sprout remembers exactly which song helps each flower grow.",
                "She would hum a hush song to the shy little shoots.",
                "There were some that could not wait and shot up fast.",
                "You know a flower likes its song when its petals shine."
            ], "Singing the growing song,"),
            ("A garden promise", "th-wh", [
                "She plans to grow a shady green tunnel for cats to explore.",
                "The vines will go this way and that way, then meet at the top.",
                "Cats can walk through it where the path is cool and the light is thin.",
                "Why does she whisper to the seeds? It is their secret, she will say."
            ], "Planning the green tunnel,")
        ]),
        cat("starlight", "Starlight", "😺", "#9D4EDD", "garden", "fireflies", 18, "firefly", "fireflies", "🌟", "the starlight spin", "💫", [
            ("The firefly friend", "l-blends", [
                "Starlight arrived on a summer night surrounded by twinkling fireflies.",
                "Two came close and then flew around her silver fur.",
                "She found that their glow would blink, and blink again.",
                "Other fireflies come to her each night, glad to have a place to play."
            ], "In the firefly meadow,"),
            ("A maker of patterns", "sh", [
                "She watches the flashes and finds secret repeating patterns in their light.",
                "There were two short flashes and then a hush.",
                "She would tap her paw by each shine.",
                "Now she could know what some of the lights should do next."
            ], "Following the flashing pattern,"),
            ("A guiding glow", "th-wh", [
                "Starlight helps late garden visitors find the path back home.",
                "They do not know which way to walk when the moon is thin.",
                "The fireflies gather on her white tail and light their way.",
                "That is why no one has to say where the path is."
            ], "Lighting the garden path,"),
            ("Her sparkling celebration", "ch", [
                "She wants to plan a firefly dance for all ten cat friends.",
                "Today each cat started to choose a spot on the porch.",
                "The fireflies will march in a chain and reach up high.",
                "‘Come here and play with me,’ she will cheer, and it will be very bright."
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
        _ beats: [(String, String, [String], String)]
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
                CatStoryBeat(id: "\(id)-\(index)", title: beat.0, focusID: beat.1, sentences: beat.2, puzzleLead: beat.3)
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
