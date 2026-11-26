import SpriteKit

/// The mission game: each round floats two or three answer bubbles in the water, and the right one feeds the shark.
final class MissionScene: SKScene {
    let mission: MissionDefinition
    let rounds: [MissionChallenge]
    /// Called with the number of rounds finished so far.
    var onCorrect: ((Int) -> Void)?
    var onWrong: (() -> Void)?
    var onMiss: (() -> Void)?
    private var surface: SKShapeNode?
    private var round = 0
    private var bubbles: [SKShapeNode] = []
    private var ruledOut: Set<Int> = []
    private var lockedUntil: TimeInterval = 0

    init(mission: MissionDefinition, rounds: [MissionChallenge], size: CGSize) {
        self.mission = mission
        self.rounds = rounds
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.01, green: 0.18, blue: 0.32, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        // These scenes are silent. SpriteKit otherwise runs its own audio engine, which can make the
        // narration hiccup each time a scene comes on screen.
        audioEngine.stop()
        if mission.kind == "ambushApproach", surface == nil {
            let surface = SKShapeNode()
            surface.fillColor = UIColor(red: 0.78, green: 0.95, blue: 1, alpha: 0.35)
            surface.strokeColor = .clear
            surface.zPosition = -1
            addChild(surface)
            self.surface = surface
        }
        if children.filter({ $0.name == "mote" }).isEmpty {
            for index in 0..<24 {
                let mote = SKShapeNode(circleOfRadius: CGFloat(2 + index % 4))
                mote.name = "mote"
                mote.fillColor = UIColor.white.withAlphaComponent(0.18)
                mote.strokeColor = .clear
                mote.position = CGPoint(x: size.width * CGFloat((index * 97) % 100) / 100, y: size.height * CGFloat((index * 61) % 100) / 100)
                addChild(mote)
                mote.run(.repeatForever(.sequence([.moveBy(x: 8, y: 14, duration: 2.5 + Double(index % 3)), .moveBy(x: -8, y: -14, duration: 2.5 + Double(index % 3))])))
            }
        }
        layout()
        if bubbles.isEmpty { showRound() }
    }

    override func didChangeSize(_ oldSize: CGSize) { layout() }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, round < rounds.count, touch.timestamp >= lockedUntil else { return }
        let point = touch.location(in: self)
        // A generous hit area: small fingers rarely land dead centre.
        guard let index = bubbles.indices.first(where: { !ruledOut.contains($0) && bubbles[$0].frame.insetBy(dx: -10, dy: -10).contains(point) }) else {
            ripple(at: point)
            onMiss?()
            return
        }
        let bubble = bubbles[index]
        if index == rounds[round].answer {
            round += 1
            burst(at: bubble.position)
            for other in bubbles where other !== bubble { other.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()])) }
            bubble.run(.sequence([.scale(to: 1.25, duration: 0.14), .wait(forDuration: 0.25), .fadeOut(withDuration: 0.2), .removeFromParent()]))
            bubbles = []
            onCorrect?(round)
            if round < rounds.count { run(.sequence([.wait(forDuration: 0.75), .run { [weak self] in self?.showRound() }])) }
        } else {
            // The wrong bubble sinks out of play, and a short pause stops answers being found by tapping everything.
            ruledOut.insert(index)
            lockedUntil = touch.timestamp + 0.9
            bubble.isAccessibilityElement = false
            bubble.run(.sequence([
                .moveBy(x: -14, y: 0, duration: 0.06), .moveBy(x: 28, y: 0, duration: 0.08), .moveBy(x: -28, y: 0, duration: 0.08), .moveBy(x: 14, y: 0, duration: 0.06),
                .group([.fadeAlpha(to: 0.25, duration: 0.3), .scale(to: 0.85, duration: 0.3)])
            ]))
            onWrong?()
        }
    }

    // MARK: Rounds

    private func showRound() {
        guard round < rounds.count else { return }
        ruledOut = []
        bubbles = rounds[round].choices.enumerated().map { index, choice in
            let bubble = makeBubble(for: choice)
            bubble.isAccessibilityElement = true
            // The tour test finds the right answer by this label.
            bubble.accessibilityLabel = index == rounds[round].answer ? "Mission target" : "Mission choice"
            bubble.setScale(0.2)
            addChild(bubble)
            bubble.run(.scale(to: 1, duration: 0.25))
            let drift = 0.9 + Double(index) * 0.2
            bubble.run(.repeatForever(.sequence([.moveBy(x: 0, y: 10, duration: drift), .moveBy(x: 0, y: -10, duration: drift)])))
            return bubble
        }
        layout()
    }

    private var bubbleSize: CGSize {
        CGSize(width: min(300, max(180, (size.width - 60) / 3 - 24)), height: min(210, max(150, size.height * 0.4)))
    }

    private func layout() {
        if let surface {
            surface.path = CGPath(rect: CGRect(x: 0, y: size.height * 0.8, width: size.width, height: size.height * 0.2), transform: nil)
        }
        let step = size.width / CGFloat(max(bubbles.count, 1))
        for (index, bubble) in bubbles.enumerated() {
            // Staggered heights look like things floating, not a row of buttons.
            let lift: CGFloat = index.isMultiple(of: 2) ? -22 : 22
            bubble.position = CGPoint(x: step * (CGFloat(index) + 0.5), y: size.height * 0.44 + lift)
        }
    }

    private func makeBubble(for choice: MissionChallenge.Choice) -> SKShapeNode {
        let plate = bubbleSize
        let bubble = SKShapeNode(rectOf: plate, cornerRadius: 36)
        bubble.fillColor = UIColor.white.withAlphaComponent(0.14)
        bubble.strokeColor = UIColor.white.withAlphaComponent(0.75)
        bubble.lineWidth = 4
        bubble.zPosition = 2
        switch choice {
        case .group(let count):
            // Rows of five, like a ten frame.
            let rows = (count + 4) / 5
            let cell = min((plate.width - 36) / 5, (plate.height - 36) / 2, 58)
            for item in 0..<count {
                let node = itemNode(side: cell * 0.88)
                let row = item / 5, column = item % 5
                let inRow = row == rows - 1 ? count - row * 5 : 5
                node.position = CGPoint(
                    x: (CGFloat(column) - CGFloat(inRow - 1) / 2) * cell,
                    y: (CGFloat(rows - 1) / 2 - CGFloat(row)) * cell
                )
                bubble.addChild(node)
            }
        case .numeral(let number):
            bubble.addChild(label("\(number)", size: 112))
        case .word(let word):
            bubble.addChild(label(word, size: word.count > 3 ? 72 : 84))
        case .phrase(let text):
            let phrase = label(text, size: 40)
            phrase.numberOfLines = 0
            phrase.preferredMaxLayoutWidth = plate.width - 32
            phrase.lineBreakMode = .byWordWrapping
            bubble.addChild(phrase)
        }
        return bubble
    }

    private func label(_ text: String, size: CGFloat) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = "ArialRoundedMTBold"
        label.fontSize = size
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        return label
    }

    /// One of the things this shark looks for, used for counting.
    private func itemNode(side: CGFloat) -> SKNode {
        if mission.kind == "ambushApproach" {
            let path = CGMutablePath()
            // A fish seen from below: a tail fork, then a rounded body.
            path.move(to: CGPoint(x: -0.6, y: 0.3))
            path.addLine(to: CGPoint(x: -0.3, y: 0))
            path.addCurve(to: CGPoint(x: 0.6, y: 0), control1: CGPoint(x: -0.1, y: 0.5), control2: CGPoint(x: 0.4, y: 0.42))
            path.addCurve(to: CGPoint(x: -0.3, y: 0), control1: CGPoint(x: 0.4, y: -0.42), control2: CGPoint(x: -0.1, y: -0.5))
            path.addLine(to: CGPoint(x: -0.6, y: -0.3))
            path.closeSubpath()
            var scale = CGAffineTransform(scaleX: side, y: side)
            let fish = SKShapeNode(path: path.copy(using: &scale) ?? path)
            fish.fillColor = UIColor.black.withAlphaComponent(0.8)
            fish.strokeColor = UIColor.white.withAlphaComponent(0.6)
            fish.lineWidth = 2
            return fish
        }
        if let asset = mission.play.targetAsset, let image = UIImage(named: asset) {
            return SKSpriteNode(texture: SKTexture(image: image), size: CGSize(width: side, height: side))
        }
        let symbol = SKLabelNode(text: mission.play.targetSymbol)
        symbol.fontSize = side * 0.8
        symbol.verticalAlignmentMode = .center
        symbol.horizontalAlignmentMode = .center
        return symbol
    }

    // MARK: Effects

    private func burst(at point: CGPoint) {
        for index in 0..<10 {
            let spark = SKShapeNode(circleOfRadius: 6)
            spark.fillColor = index.isMultiple(of: 2) ? .systemYellow : .white
            spark.strokeColor = .clear
            spark.position = point
            spark.zPosition = 5
            addChild(spark)
            let angle = CGFloat(index) / 10 * 2 * .pi
            spark.run(.sequence([
                .group([.moveBy(x: cos(angle) * 130, y: sin(angle) * 130, duration: 0.45), .fadeOut(withDuration: 0.45), .scale(to: 0.3, duration: 0.45)]),
                .removeFromParent()
            ]))
        }
    }

    private func ripple(at point: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: 22)
        ring.strokeColor = UIColor.white.withAlphaComponent(0.6)
        ring.lineWidth = 3
        ring.fillColor = .clear
        ring.position = point
        addChild(ring)
        ring.run(.sequence([.group([.scale(to: 2.4, duration: 0.4), .fadeOut(withDuration: 0.4)]), .removeFromParent()]))
    }
}
