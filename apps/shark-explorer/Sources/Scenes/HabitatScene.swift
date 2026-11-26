import SpriteKit

final class HabitatScene: SKScene {
    private let shark: AnimalDefinition

    init(shark: AnimalDefinition, size: CGSize) {
        self.shark = shark
        super.init(size: size)
        scaleMode = .resizeFill
        // Deep water tinted toward this shark's colour, so the photo reads clearly against it.
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        UIColor(shark.tint).getRed(&red, green: &green, blue: &blue, alpha: nil)
        backgroundColor = UIColor(red: 0.02 + red * 0.3, green: 0.16 + green * 0.3, blue: 0.3 + blue * 0.3, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        // These scenes are silent. SpriteKit otherwise runs its own audio engine, which can make the
        // narration hiccup each time a scene comes on screen.
        audioEngine.stop()
        removeAllChildren()
        let floor = SKShapeNode(rectOf: CGSize(width: size.width * 1.2, height: 70))
        floor.fillColor = UIColor(red: 0.62, green: 0.48, blue: 0.29, alpha: 0.55)
        floor.strokeColor = .clear
        floor.position = CGPoint(x: size.width / 2, y: 20)
        addChild(floor)

        let sharkNode: SKNode
        if let image = UIImage(named: shark.imageAsset) {
            let sprite = SKSpriteNode(texture: SKTexture(image: image))
            // Fit inside the tank whatever the photo's shape: wide strips and tall portraits both stay whole.
            let scale = min(min(size.width * 0.42, 380) / max(image.size.width, 1), size.height * 0.62 / max(image.size.height, 1))
            sprite.size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            sprite.name = "species-image"
            sharkNode = sprite
        } else {
            let label = SKLabelNode(text: shark.symbol)
            label.fontSize = min(size.height * 0.36, 150)
            label.verticalAlignmentMode = .center
            sharkNode = label
        }
        // Start in view so the shark is the first thing a child sees, then keep crossing the tank.
        sharkNode.position = CGPoint(x: size.width * 0.4, y: size.height * 0.56)
        addChild(sharkNode)
        let span = size.width + 440
        let finish = SKAction.moveTo(x: size.width + 220, duration: 14 * Double((size.width * 0.6 + 220) / span))
        let reset = SKAction.moveTo(x: -220, duration: 0)
        let cross = SKAction.moveTo(x: size.width + 220, duration: 14)
        sharkNode.run(.sequence([finish, .repeatForever(.sequence([reset, cross]))]))
        sharkNode.run(.repeatForever(.sequence([.moveBy(x: 0, y: 10, duration: 1.6), .moveBy(x: 0, y: -10, duration: 1.6)])))

        for index in 0..<16 {
            let bubble = SKShapeNode(circleOfRadius: CGFloat(2 + index % 6))
            bubble.strokeColor = UIColor.white.withAlphaComponent(0.35)
            bubble.position = CGPoint(x: size.width * CGFloat((index * 73) % 100) / 100, y: size.height * CGFloat((index * 41) % 100) / 100)
            addChild(bubble)
            bubble.run(.repeatForever(.sequence([
                .moveBy(x: 12, y: size.height + 30, duration: 5 + Double(index % 4)),
                .moveBy(x: -12, y: -(size.height + 30), duration: 0)
            ])))
        }
    }
}
