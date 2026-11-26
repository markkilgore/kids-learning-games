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

    /// Pages in the first chapter. They open one round apart from the very first puzzle.
    static let chapterOnePages = 4

    /// The friendship level at which chapter two (page 5 onward) begins. The meadow animals carry straight on
    /// after chapter one. The ten cats' second chapter was written after Kate had reached 25 hearts with each of
    /// them, so theirs starts at 27: the pages open one round at a time instead of all at once.
    var chapterTwoStart: Int { locationID == "meadow" ? Self.chapterOnePages * Self.puzzlesPerRound : 27 }

    func isInChapterTwo(at friendship: Int) -> Bool { backstory.count > Self.chapterOnePages && friendship >= chapterTwoStart }

    /// The friendship level that opens a page.
    func friendshipNeeded(forPage page: Int) -> Int {
        page < Self.chapterOnePages ? page * Self.puzzlesPerRound : chapterTwoStart + (page - Self.chapterOnePages) * Self.puzzlesPerRound
    }

    /// The story page a cat is on: a new page opens each time a round of puzzles is finished.
    func storyPage(for friendship: Int) -> Int {
        (0..<backstory.count).last { friendshipNeeded(forPage: $0) <= max(friendship, 0) } ?? 0
    }

    func storyBeat(for friendship: Int) -> CatStoryBeat { backstory[storyPage(for: friendship)] }

    func revealedStory(for friendship: Int) -> [CatStoryBeat] {
        Array(backstory.prefix(storyPage(for: friendship) + 1))
    }

    /// Puzzles already solved in the round this friendship level is part of.
    func solvedInRound(for friendship: Int) -> Int { max(friendship, 0) % Self.puzzlesPerRound }

    /// The friendship level at which the last story page opens.
    var lastPageFriendship: Int { friendshipNeeded(forPage: backstory.count - 1) }

    /// Puzzles still to solve before the next page opens, or nil once every page is open.
    func puzzlesUntilNextPage(for friendship: Int) -> Int? {
        let next = storyPage(for: friendship) + 1
        return next < backstory.count ? friendshipNeeded(forPage: next) - max(friendship, 0) : nil
    }

    /// Whether finishing the round that starts at this friendship level opens a page.
    func roundOpensPage(from friendship: Int) -> Bool {
        storyPage(for: friendship + Self.puzzlesPerRound) > storyPage(for: friendship)
    }
}

enum CatContent {
    static let locations = [
        LearningLocation(id: "house", name: "House", symbol: "house.fill"),
        LearningLocation(id: "garden", name: "Garden", symbol: "leaf.fill"),
        LearningLocation(id: "meadow", name: "Meadow", symbol: "sun.max.fill")
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
            ], "To finish the patchwork blanket,"),
            ("The first square", "l-blends", [
                "Mittens found a blue cloth and a plaid one to start her blankets.",
                "Two other cats came to help her clip the loose threads.",
                "They worked until the floor was full of fluffy scraps.",
                "Mittens was glad, and she placed the first square on a clean pillow."
            ], "Cutting the blanket squares,"),
            ("The missing buttons", "sh", [
                "Some shiny buttons were gone from the tin on the shelf.",
                "Mittens did not know where they could be, so she looked by the door.",
                "There they were, in a shoe, pushed under a shirt.",
                "She would call that a good wish come true."
            ], "Searching for the shiny buttons,"),
            ("Help from friends", "th-wh", [
                "Pepper and Biscuit asked what they could do with the thread.",
                "Mittens showed them the right way to pull it through the cloth.",
                "Their paws went up and down while the white yarn grew thin.",
                "‘Why, this is fun,’ they say, and nobody wants to walk off."
            ], "At the sewing circle,"),
            ("Blankets for all", "ch", [
                "Today Mittens started to give each cat a patchwork blanket.",
                "She put one on the chair and one on the kitchen bench.",
                "‘Here is one for me, too,’ she said with a cheerful purr.",
                "The cats chose to play, then nap, and it will be a very snug night."
            ], "Sharing the patchwork blankets,")
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
            ], "Drawing the sunbeam map,"),
            ("The finished map", "sh", [
                "Pepper’s sunbeam map was finished, and he could not wait to share it.",
                "He would show it to some friends by the bookshelf.",
                "There were gold shapes for the sun and gray ones for the shade.",
                "‘You know, we should call it the Shine Map,’ said Biscuit."
            ], "Showing the sunbeam map,"),
            ("A cloudy day", "ch", [
                "Today the sky was gray, and each patch of sun was gone.",
                "Pepper sat on his chair and started to check the map.",
                "‘There is not much here for me to use,’ he said.",
                "Then he chose to be very calm and watch for a change."
            ], "On a gray, cloudy day,"),
            ("A spark of sun", "s-blends", [
                "Before lunch, a small spot of sun slid into the hall.",
                "Pepper does a quick skip and stops to sniff the warm floor.",
                "‘Don’t step on it,’ he says, and the spot starts to grow.",
                "After that, no cat is still, and they all stretch in the glow."
            ], "Watching the sunny spot grow,"),
            ("Sun for everyone", "th-wh", [
                "Pepper knows where the sun goes and which way it will turn.",
                "He shows the other cats their own warm path with a nod.",
                "They walk to the right when the light slips that way.",
                "‘Why jump for sun,’ they say, ‘when Pepper can tell us where it is?’"
            ], "Leading the sunbeam walk,")
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
            ], "Building the reading fort,"),
            ("The fort begins", "th-wh", [
                "Biscuit thinks this is the day to start the reading fort.",
                "She knows where the thick pillows are and which way to pull them.",
                "With three tugs, they slide right to their place by the white wall.",
                "‘Why walk when you can jump?’ she likes to say, and then she hops on top."
            ], "Starting the reading fort,"),
            ("A sagging roof", "sh", [
                "There was a sheet for the roof, but it would not stay up.",
                "It could slip and swish down on some cushions by the shelf.",
                "Biscuit did not know what to do, so she gave a call.",
                "Poppy and Pepper were there in a flash to push it back."
            ], "Under the sagging sheet,"),
            ("Many paws help", "l-blends", [
                "Two other cats came with clips, and Poppy found a long flag pole.",
                "They worked to place the pole and clamp the blue sheet flat.",
                "People walking around the fort could see it glow like a cloud.",
                "Biscuit was so glad that she had to clap her paws."
            ], "Clipping the fort roof,"),
            ("Story time", "s-blends", [
                "After the last pillow is in its spot, the fort is snug.",
                "Biscuit does not start before all her friends step inside.",
                "They snuggle into the blankets, and no cat is left out.",
                "Small stars shine on the sheet as the first story starts to grow."
            ], "Inside the snug reading fort,")
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
            ], "Planning the cardboard village,"),
            ("The village begins", "ch", [
                "Today Poppy started the cardboard village with a chalk line.",
                "She chose a spot for each castle and a church with a bell.",
                "‘Here is a porch for me,’ said Waffles, ‘and I will use it very well.’",
                "There will be much to do, so the cats munch lunch and then play."
            ], "Along the chalk line,"),
            ("A windy wobble", "l-blends", [
                "A blast of wind came in and made the flags flap.",
                "Two towers slid flat, and the other one began to slip.",
                "Poppy found the glue, and her helpers worked to clamp each wall.",
                "The people came around to clap when the last flag flew."
            ], "Fixing the wobbly towers,"),
            ("Paths and bridges", "th-wh", [
                "Poppy thinks about which path should go to which castle.",
                "She shows the cats where to walk and the right way to turn.",
                "They jump on the thin bridge, and it holds with their weight.",
                "‘Why, that is the best thing we have made,’ they say."
            ], "Testing the cardboard bridge,"),
            ("The grand opening", "s-blends", [
                "Before the sun sets, Poppy stands on the top step.",
                "She does a royal spin and snips the string with a smile.",
                "Her friends skip into the village, and no cat has to stay out.",
                "After the stars come out, small lights grow bright in each castle."
            ], "At the village gate,")
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
            ], "Preparing the pancake picnic,"),
            ("Picnic morning", "s-blends", [
                "Before the sun is up, Waffles steps into the still kitchen.",
                "He does not stop to snack, for he has a stack to make.",
                "He stirs with a spoon and smells the sweet steam grow.",
                "After that, no pancake is too small to go on the plate."
            ], "Stirring the pancake batter,"),
            ("The berry spill", "sh", [
                "Some berries were in a dish, but the dish could not hold them.",
                "They went splash on the floor and rolled there by the shelf.",
                "Waffles did not know if he should rush or wait.",
                "He would call for help, and Mittens came in a flash to push them back."
            ], "Chasing the spilled berries,"),
            ("Setting the blanket", "l-blends", [
                "Two cats came to help him place a plaid blanket on the grass.",
                "Clover found flowers, and the other helpers set out blue plates.",
                "They worked until each glass was clean and every plum was sliced.",
                "People walking around the garden could see the picnic glow."
            ], "Setting out the picnic plates,"),
            ("A happy feast", "th-wh", [
                "Waffles shows his friends where to sit and which plate is theirs.",
                "They say thanks, and then they munch with both cheeks full.",
                "‘Why not jump and dance?’ he asks, and they walk right to the grass.",
                "That is the way their best day ends, with three cheers for Waffles."
            ], "At the pancake picnic,")
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
            ], "Growing the butterfly garden,"),
            ("Planting day", "l-blends", [
                "Clover came to the garden bed with two clay pots of blue flowers.",
                "She found a flat place where the plants could get sun.",
                "The other cats worked beside her and patted the cool soil down.",
                "By lunch, glad butterflies had come around to float above each bloom."
            ], "Planting the blue flowers,"),
            ("A sudden shower", "sh", [
                "A sudden shower began to splash the new butterfly garden.",
                "Some butterflies could not fly with wet wings, so they shook and shivered.",
                "Clover would call them to the shelter by the shady bush.",
                "There they were, safe and dry, until the sun began to shine."
            ], "Sheltering from the shower,"),
            ("The butterfly bench", "ch", [
                "Today Clover started to check on each flower after the rain.",
                "A branch had dropped on the bench where the butterflies like to perch.",
                "‘Come here and help me,’ she chirped, and Ginger gave it a push.",
                "Now the bench can be a very cheerful place to rest and play."
            ], "Clearing the butterfly bench,"),
            ("The garden party", "th-wh", [
                "When the flowers opened, Clover asked all her friends to the garden.",
                "They knew the right way to walk, along the path that she had shown them.",
                "Butterflies landed on their ears and whiskers, and nobody wanted to jump.",
                "Why was Clover purring? Her butterfly garden was the best thing she had ever made."
            ], "At the butterfly garden party,")
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
            ], "Making Moon’s star map,"),
            ("Naming the stars", "sh", [
                "Moon sat by the garden wall and began to name the stars that shine.",
                "There were some she could call by the shapes they made.",
                "One would be Fish, one would be Ship, and a small one would be Shell.",
                "She did not know them all yet, but she was not in a rush."
            ], "Naming stars by the wall,"),
            ("A cloudy night", "l-blends", [
                "One night, gray clouds came and hid the stars like a blanket.",
                "Moon found she could not see a single glow in the black sky.",
                "Two other cats came around to sit close and keep her company.",
                "Then a breeze blew, the clouds slid away, and the sky was clear."
            ], "Waiting for the clouds to pass,"),
            ("A star for each friend", "th-wh", [
                "Moon thinks each friend should have a star of their own.",
                "She knows where Clover’s star sits, right above the path.",
                "This one is for Sprout, and that white one is for Starlight.",
                "Why not say good night to them all on the way to bed?"
            ], "Choosing a star for each friend,"),
            ("The star show", "s-blends", [
                "Before the sky is dark, Moon spreads a soft blanket on the stone step.",
                "Her friends snuggle close, and she does not start until they are still.",
                "‘Don’t blink,’ she says, as small stars slip into the sky.",
                "After the last star is named, no cat wants to stop looking up."
            ], "At Moon’s star show,")
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
            ], "Designing the obstacle course,"),
            ("Building the course", "th-wh", [
                "Ginger thought about where each part of the course should go.",
                "The stepping stones went this way, then that way, then through the thick ferns.",
                "He put a white rope where cats could jump, and a log where they could walk.",
                "Why did he test it three times? He wanted every path to be just right."
            ], "Setting out the course,"),
            ("A slippery problem", "l-blends", [
                "Two stones by the stream were too slick, and a kitten slid off.",
                "Ginger found flat, dry stones and placed them close together.",
                "The other cats came to help, and they worked until the gap was closed.",
                "Glad cats clapped when the kitten came around again and did not slip."
            ], "Fixing the slippery stones,"),
            ("Race day", "ch", [
                "Today the garden course is open, and each cat can choose a turn.",
                "Poppy started first and cleared the branch with a cheerful hop.",
                "‘Watch me!’ called Sprout, as she chased a leaf past the bench.",
                "It was very good to be here and play, even for the cats who only watched."
            ], "On race day in the garden,"),
            ("The last stone", "s-blends", [
                "Before the last race, a small kitten stood still at the start.",
                "‘Don’t stop,’ said Ginger, ‘just step onto one stone and then the next.’",
                "She does a little skip, then a spring, and sails into the soft grass.",
                "After that, no cat smiled more than Ginger, and his pride began to grow."
            ], "Cheering at the finish stone,")
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
            ], "Planning the green tunnel,"),
            ("The first arch", "ch", [
                "Today Sprout started the green tunnel with one bent branch.",
                "She chose a spot by the bench and tied each vine with string.",
                "‘Come here and reach up for me,’ she said, and Ginger held the arch.",
                "It will be a very long time before cats can play under it, but she is cheerful."
            ], "Bending the first arch,"),
            ("Slow and steady", "s-blends", [
                "The little vines start out small, and they do not grow in one day.",
                "Before the sun gets hot, Sprout sprinkles water on each stem.",
                "She does not skip a pot, and she sweeps the snails into the grass.",
                "After a week, no stem is slumped, and tiny leaves spread wide."
            ], "Sprinkling the tunnel vines,"),
            ("Helpers arrive", "l-blends", [
                "The vines began to climb, but one side of the tunnel flopped down.",
                "Clover and Moon came around with two long sticks to hold it up.",
                "The other cats found clips and worked to fix every plant in place.",
                "Sprout was glad that her friends had come to help."
            ], "Fixing the floppy vines,"),
            ("The shady tunnel", "sh", [
                "By summer, the tunnel was finished, and its leaves made cool shade.",
                "There were some sunny patches that would shine through and shift on the path.",
                "The cats could dash in, shuffle along, and share a nap inside.",
                "Sprout would not call it her tunnel, for she knows it belongs to them all."
            ], "Inside the shady green tunnel,")
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
            ], "Planning the firefly dance,"),
            ("Practice steps", "s-blends", [
                "Before the big dance, Starlight shows her friends the first steps.",
                "She does a slow spin, then a small skip, and stops with a bow.",
                "‘Don’t rush,’ she says, as the fireflies swirl into a line.",
                "After a few tries, no cat stumbles, and the lights sparkle in time."
            ], "Practicing the dance steps,"),
            ("The missing light", "ch", [
                "Today one little firefly could not catch up with the chain.",
                "Starlight started to search by the porch and under each chair.",
                "‘Come here to me,’ she chirped, and a tiny glow reached her paw.",
                "The firefly was very glad to be found and went back to play."
            ], "Searching for the little firefly,"),
            ("Flags and flowers", "l-blends", [
                "Two cats came with glass jars to make the porch glow.",
                "Other cats found blue flowers and placed them around the steps.",
                "Clover worked on a flag, and Moon cleaned the floor with her tail.",
                "When people come by, they will see a place that glitters like the sky."
            ], "Decorating the porch,"),
            ("The firefly dance", "th-wh", [
                "When the moon came up, the fireflies knew the right way to fly.",
                "They made a white wheel in the air, then a path of light that went up and up.",
                "The cats did not just walk, for their paws wanted to jump and spin.",
                "Why did Starlight thank them all? It was the best night she had ever had."
            ], "At the firefly dance,")
        ]),
        cat("scout", "Scout", "🐶", "#C68642", "meadow", "his squeaky ball", 100, "stick", "sticks", "🪵", "the tail-wag twirl", "🌀", [
            ("The muddy visitor", "sh", [
                "Scout dashed into the meadow one spring day with a squeaky ball in his mouth.",
                "There were splashes of mud on his short brown legs.",
                "He shook himself by the fence, and some mud landed on a bush.",
                "You would know him by his floppy ears and his wish to share."
            ], "Beside the meadow gate,"),
            ("The stick finder", "th-wh", [
                "Scout gathers fallen sticks so that the path stays clear for everyone.",
                "He knows where they hide and which way the wind blows them.",
                "With a jump and a wag, he carries them to their pile.",
                "That is why the other animals can walk through without a trip."
            ], "Along the meadow path,"),
            ("The lost squeak", "ch", [
                "Today Scout’s squeaky ball rolled away and landed in a ditch.",
                "He started to search each patch of clover, inch by inch.",
                "A chipmunk came to cheer him on and chose a spot to check.",
                "‘Here it is!’ chirped the chipmunk, and Scout was very glad to play."
            ], "Searching the clover patch,"),
            ("A stick-fort dream", "s-blends", [
                "Scout dreams of a snug stick fort where his friends can stay dry.",
                "Before he starts, he sorts the small sticks from the strong ones.",
                "He does not stop to snack, and he doesn’t skip a step.",
                "After a while, the stack will grow into a home for everyone."
            ], "Planning the stick fort,"),
            ("The fort begins", "l-blends", [
                "Scout found a flat place by the plum tree to build his stick fort.",
                "Two friends came to help, and Clover brought a bundle of sticks.",
                "The other helpers worked to place each stick and close the gaps.",
                "When people come around, they clap for the walls and the little blue flag."
            ], "Beside the plum tree,"),
            ("A windy wobble", "sh", [
                "A sharp gust of wind made the stick fort shiver and shake.",
                "There were gaps by the door, and some sticks could slip out.",
                "Scout would not give up, so he dashed off to find fresh mud.",
                "‘I know what to do,’ he said, and he pushed mud into each gap."
            ], "Patching the windy fort,"),
            ("Friends pitch in", "th-wh", [
                "Then Hazel and Bramble came with moss to make the walls thick.",
                "They knew which gaps to fill and where the roof was thin.",
                "Puddle showed them the right way to pat the mud smooth.",
                "‘Why not work together?’ they say, and their fort grows strong."
            ], "Working together at the fort,"),
            ("The fort party", "ch", [
                "Today the stick fort is finished, and every friend can be here.",
                "Scout started the party with a cheerful tail-wag twirl by the porch.",
                "Each friend chose a spot on the bench to munch a snack.",
                "‘Come and play with me,’ said Scout to the very happy bunch."
            ], "At the stick-fort party,")
        ]),
        cat("hazel", "Hazel", "🐰", "#9A8C98", "meadow", "crunchy carrots", 150, "carrot", "carrots", "🥕", "the bunny binky", "🐇", [
            ("The clover-patch bunny", "th-wh", [
                "Hazel hopped into the meadow on a path of thick white clover.",
                "She did not know where to rest, so she sat with the daisies.",
                "The other animals came to say hello, and that made her whiskers twitch.",
                "Then she did a happy jump, and they made room in their burrow."
            ], "In the white clover,"),
            ("A crunchy helper", "ch", [
                "Hazel shares her crunchy carrots so that nobody has an empty lunch.",
                "Today she started to fetch a bunch from the garden patch.",
                "She will use her teeth to chop each one for the chicks.",
                "‘Here is some for you and some for me,’ she says, and they are very glad."
            ], "Sharing the carrot lunch,"),
            ("The secret tunnel", "s-blends", [
                "Hazel knows a snug tunnel that slips under the stone wall.",
                "Before the stars come out, she sneaks into it without a sound.",
                "She does not stop until she smells the sweet garden leaves.",
                "After a small snack, she skips home, and no one sees her go."
            ], "By the secret bunny tunnel,"),
            ("A carrot-patch plan", "l-blends", [
                "Hazel plans to plant a carrot patch big enough for every friend.",
                "She found a flat, sunny place where the clay is soft.",
                "Two other bunnies came to dig, and they worked until the clouds turned pink.",
                "When the green tops come up, people all around will clap."
            ], "Planning the carrot patch,"),
            ("The first shoots", "sh", [
                "Hazel’s seeds pushed up fresh green shoots after a soft spring shower.",
                "There were some by the fence and some in the shade.",
                "She could not wait, but she knew she should let them grow.",
                "‘I would call that a fine start,’ she said, and her nose shook with joy."
            ], "Checking the green shoots,"),
            ("The thirsty patch", "th-wh", [
                "Then three hot days went by, and the carrot tops grew thin.",
                "Hazel did not know which way to carry water from the pond.",
                "‘Why not ask Puddle?’ thought Hazel, and she hopped down the path.",
                "They could walk there together, and that was the right thing to do."
            ], "On the way to the pond,"),
            ("A water chain", "ch", [
                "Today the friends made a chain to reach from the pond to the patch.",
                "Puddle started to fill each cup, and Scout chose to carry them.",
                "Maple let them use her back to fetch much more.",
                "‘Play here by me,’ said Hazel, and the chore felt very much like a game."
            ], "Along the water chain,"),
            ("The carrot feast", "s-blends", [
                "After the rain, Hazel’s carrots stand tall on strong green stems.",
                "She pulls them up and does a bunny binky before she stops to smile.",
                "Her friends wash the carrots and stack them into a small, sweet pile.",
                "No one goes hungry, and don’t worry, the patch will grow again next spring."
            ], "At the carrot feast,")
        ]),
        cat("puddle", "Puddle", "🐥", "#7FB7BE", "meadow", "rainy days", 255, "lily pad", "lily pads", "🪷", "the puddle splash", "💦", [
            ("The rainy-day chick", "ch", [
                "Puddle hatched by the pond on a very rainy day in March.",
                "He started to cheep, and each raindrop made him chuckle.",
                "Today he likes to perch on a branch and watch the drops.",
                "‘Come here and play with me,’ he calls, and soon the pond will be full of friends."
            ], "By the rainy pond,"),
            ("The lily-pad sweeper", "s-blends", [
                "Puddle sweeps the lily pads so small frogs have clean places to sit.",
                "Before the sun is up, he swims out and starts to scrub.",
                "He does not skip a spot, and he doesn’t splash the snails.",
                "After that, he will wash his feet and slide into the reeds."
            ], "Sweeping the lily pads,"),
            ("A brave float", "l-blends", [
                "Puddle once floated across the whole pond to bring back a lost blue feather.",
                "He found it on a flat stone, close to the tall plants.",
                "Two other ducklings came to cheer, and they clapped their wings.",
                "He glided home around the reeds, glad that he had worked so hard."
            ], "Floating across the pond,"),
            ("A splashy wish", "sh", [
                "Puddle wishes he could host a splash show for every friend.",
                "There would be a stage by the shore made of shiny shells.",
                "Some friends could dash, and some could shake their feathers.",
                "He does not know when it will be, but he will call them all."
            ], "Dreaming up the splash show,"),
            ("Getting things ready", "th-wh", [
                "Puddle thinks about where each friend should stand for the show.",
                "He marks the path with white pebbles so they know which way to walk.",
                "Then he tells them when to jump and what to say.",
                "That is why their smiles are wide, and everything feels right."
            ], "Marking the pebble path,"),
            ("Not a drop", "ch", [
                "Today the sky is very dry, and the pond is too low to splash much.",
                "Puddle started to watch each cloud and scratch his chin.",
                "‘Rain would be such a help,’ he said to a finch on a branch.",
                "‘Stay here with me,’ chirped the finch, ‘and we can use the creek.’"
            ], "Watching for rain clouds,"),
            ("A stream of help", "s-blends", [
                "Scout and Maple scoop a small path so the stream can spill into the pond.",
                "Before long, the water starts to swirl, and the pond steps up higher.",
                "Puddle does a happy spin, and no one stands still.",
                "After the work, the friends wash off the mud, and they don’t stop smiling."
            ], "Digging the little stream,"),
            ("The splash show", "l-blends", [
                "People and animals came from all around to clap for the splash show.",
                "Two frogs flipped off a plank, and the other ducklings glided in a ring.",
                "Puddle found his place and did the biggest puddle splash of all.",
                "Then clouds rolled in, rain fell, and all were glad they had worked so hard."
            ], "At the splash show,")
        ]),
        cat("bramble", "Bramble", "🦔", "#A47148", "meadow", "crunchy leaves", 265, "acorn", "acorns", "🌰", "the hedgehog roll", "🍂", [
            ("The shy snuffler", "s-blends", [
                "Bramble was found asleep under a stack of crunchy leaves by a stump.",
                "Before she peeks out, she sniffs the air and stays very still.",
                "She does not speak much, but her small smile is sweet.",
                "After a while, she steps into the sun, and no one makes a sound."
            ], "Beside the mossy stump,"),
            ("The acorn keeper", "l-blends", [
                "Bramble found a hollow log and made it a place to keep acorns safe.",
                "Two squirrels came by, glad to see a clean, dry spot.",
                "She worked to pile the acorns in a cluster under a blanket of leaves.",
                "When cold winds blow around, the other animals come for a snack."
            ], "Inside the hollow log,"),
            ("Braver than her prickles", "sh", [
                "One night, a little mouse was lost in the shadows by the shed.",
                "Bramble could hear a hush and then a shaky squeak.",
                "There were no stars, but she would not rush away.",
                "‘I know the way,’ she said, and she shuffled ahead to show the mouse home."
            ], "In the evening shadows,"),
            ("A leafy thought", "th-wh", [
                "Bramble thinks a leaf slide would be the best thing in the meadow.",
                "She knows where the hill is and which way the leaves fall.",
                "With a thick pile at the bottom, they could all jump in.",
                "That is why she whispers her plan to the moths, who say it sounds right."
            ], "Planning the leaf slide,"),
            ("Leaves by the bunch", "ch", [
                "Today Bramble started to fetch leaves for the slide, a bunch at a time.",
                "She can use her prickles to catch each one as she rolls.",
                "A robin on a branch chirped, ‘Let me help you reach the top.’",
                "It will be a very big job, but here she goes, ready to play."
            ], "Gathering leaves for the slide,"),
            ("A sticky spot", "s-blends", [
                "The slide is too slow, for the damp leaves stick and do not slip.",
                "Bramble stops to think before she starts again.",
                "She does not stamp her feet; she spreads the leaves to dry in the sun.",
                "After lunch they will grow crisp, and no leaf will stay stuck."
            ], "Drying the damp leaves,"),
            ("Helpers on the hill", "l-blends", [
                "Hazel and Scout came around the hill with a flat sled of dry leaves.",
                "The other helpers worked to fluff the pile and clear the stones.",
                "Two cats, Sprout and Ginger, found a plank to make the slide glide.",
                "‘Come and climb up,’ they called, and Bramble’s face began to glow."
            ], "On the leafy hill,"),
            ("The whoosh down", "sh", [
                "Bramble tucked into a ball and did her hedgehog roll with a whoosh.",
                "She shot down the slide and landed in a crunchy leaf shower.",
                "There were cheers by the hill, and some friends could not wait for a turn.",
                "‘I wish you would all call this our slide,’ she said in a shy, happy voice."
            ], "At the bottom of the leaf slide,")
        ]),
        cat("maple", "Maple", "🐴", "#BC6C25", "meadow", "red apples", 280, "apple", "apples", "🍎", "the happy trot", "🎠", [
            ("The gentle newcomer", "l-blends", [
                "Maple came to the meadow barn with a blue ribbon on her mane.",
                "She found a clean stall and a plump pile of clover.",
                "Two cats, Clover and Moon, came around to greet her.",
                "The other animals were glad, for she let the small ones climb on her back."
            ], "In the meadow barn,"),
            ("Apples to share", "sh", [
                "Maple knows which apples in the orchard are fresh and sweet.",
                "There were some on a low branch that she could reach with a gentle shake.",
                "She would push them by the fence so the short animals could share.",
                "You might call her the kindest pony, and she shines when she hears it."
            ], "Under the orchard branches,"),
            ("The thunder night", "th-wh", [
                "One night the thunder rumbled, and three small chicks did not know where to go.",
                "Maple stood with them and showed them the way to the barn.",
                "They could walk under her thick, warm mane the whole path.",
                "That is why they say she is brave, and their hearts feel light when she is near."
            ], "On the path to the barn,"),
            ("An orchard wish", "ch", [
                "Maple hopes to hold a harvest lunch beneath the orchard trees.",
                "Today she started to choose which apples to pick for each friend.",
                "There will be a bench for the chicks and a chair for the cats.",
                "‘Sit here by me and play,’ she will say, and it will be a very cheerful day."
            ], "Planning the harvest lunch,"),
            ("Stacking the baskets", "s-blends", [
                "Before the sun is high, Maple starts to stack baskets by the stable.",
                "She steps into the orchard and stops under a tree full of red apples.",
                "Her friends spread a cloth and wash each apple until it sparkles.",
                "No one snacks yet, and they don’t stop until every basket is full."
            ], "Stacking apple baskets,"),
            ("A basket tumble", "l-blends", [
                "A full basket slid off the cart, and apples rolled across the flat ground.",
                "Maple found some in the flowers and some close to the plum tree.",
                "Two helpers came, and the other animals worked to place them back.",
                "Soon people all around could come and see a clean, glowing pile."
            ], "Picking up the rolling apples,"),
            ("Shade for everyone", "sh", [
                "The noon sun was sharp, and there were no trees by the long table.",
                "Maple knew she could push the old sheet up on some poles.",
                "‘I know it would make fine shade,’ she said, and Scout dashed to help.",
                "Soon a wide shadow fell, and they could call the lunch ready."
            ], "Under the shady sheet,"),
            ("The harvest lunch", "th-wh", [
                "Then the friends sat together with apples, carrots, and warm bread.",
                "Maple did her happy trot the whole way around the white cloth.",
                "They thanked her, and she showed them where to jump in the hay.",
                "‘This is the right place for us,’ they say, and that is why their meadow feels like home."
            ], "At the harvest lunch,")
        ])
    ]

    static let skills = [
        EducationalSkill(id: "counting", displayName: "Counting"),
        EducationalSkill(id: "addition", displayName: "Addition"),
        EducationalSkill(id: "subtraction", displayName: "Subtraction"),
        EducationalSkill(id: "odd-even", displayName: "Odd and even"),
        EducationalSkill(id: "skip-5", displayName: "Skip counting by 5"),
        EducationalSkill(id: "skip-10", displayName: "Skip counting by 10"),
        EducationalSkill(id: "doubles", displayName: "Doubles"),
        EducationalSkill(id: "skip-2", displayName: "Skip counting by 2")
    ]

    /// The six skills each chapter rotates through. Chapter two uses bigger numbers and swaps in doubles and twos.
    static let chapterOneSkillIDs = ["counting", "addition", "subtraction", "odd-even", "skip-5", "skip-10"]
    static let chapterTwoSkillIDs = ["addition", "subtraction", "doubles", "odd-even", "skip-2", "skip-5"]

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
        progression: ProgressionRules(model: "friendship", pointsPerSuccess: 1, unlockThresholds: [0, 4, 6, 9, 12, 18, 100, 150, 255, 265, 280]),
        storageNamespace: "com.mkilgore.CatMathAdventure.kate",
        featureFlags: FeatureFlags(["journal": true, "visualHints": true, "narratedPrompts": true])
    )
}
