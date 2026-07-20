import SpriteKit

final class HabitatScene: SKScene {
    private let shark: SharkDefinition

    init(shark: SharkDefinition, size: CGSize) {
        self.shark = shark
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = UIColor(shark.tint.opacity(0.22))
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        removeAllChildren()
        let floor = SKShapeNode(rectOf: CGSize(width: size.width * 1.2, height: 70))
        floor.fillColor = UIColor(red: 0.62, green: 0.48, blue: 0.29, alpha: 0.55)
        floor.strokeColor = .clear
        floor.position = CGPoint(x: size.width / 2, y: 20)
        addChild(floor)

        let sharkNode: SKNode
        if let image = UIImage(named: shark.imageAsset) {
            let sprite = SKSpriteNode(texture: SKTexture(image: image))
            let targetWidth = min(size.width * 0.42, 380)
            let aspect = image.size.height / max(image.size.width, 1)
            sprite.size = CGSize(width: targetWidth, height: targetWidth * aspect)
            sprite.name = "species-image"
            sharkNode = sprite
        } else {
            let label = SKLabelNode(text: shark.symbol)
            label.fontSize = min(size.height * 0.36, 150)
            label.verticalAlignmentMode = .center
            sharkNode = label
        }
        sharkNode.position = CGPoint(x: -220, y: size.height * 0.54)
        addChild(sharkNode)
        let swim = SKAction.moveTo(x: size.width + 220, duration: 10)
        let reset = SKAction.moveTo(x: -220, duration: 0)
        sharkNode.run(.repeatForever(.sequence([swim, reset])))

        for index in 0..<16 {
            let bubble = SKShapeNode(circleOfRadius: CGFloat(2 + index % 6))
            bubble.strokeColor = UIColor.white.withAlphaComponent(0.35)
            bubble.position = CGPoint(x: CGFloat((index * 73) % 900), y: CGFloat((index * 41) % 300))
            addChild(bubble)
            bubble.run(.repeatForever(.sequence([
                .moveBy(x: 12, y: size.height + 30, duration: 5 + Double(index % 4)),
                .moveBy(x: -12, y: -(size.height + 30), duration: 0)
            ])))
        }
    }
}
