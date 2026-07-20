import SpriteKit

final class MissionScene: SKScene {
    let mission: MissionDefinition
    var onProgress: ((Int) -> Void)?
    private var hits = 0
    private var target: SKLabelNode?

    init(mission: MissionDefinition, size: CGSize) {
        self.mission = mission
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.01, green: 0.18, blue: 0.32, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        for index in 0..<24 {
            let mote = SKShapeNode(circleOfRadius: CGFloat(2 + index % 4))
            mote.fillColor = UIColor.white.withAlphaComponent(0.18)
            mote.strokeColor = .clear
            mote.position = CGPoint(x: CGFloat((index * 97) % 1000), y: CGFloat((index * 61) % 500))
            addChild(mote)
        }
        spawnTarget()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self), let target else { return }
        if target.contains(point) {
            hits += 1
            onProgress?(hits)
            target.run(.sequence([.scale(to: 1.45, duration: 0.12), .fadeOut(withDuration: 0.16), .removeFromParent()]))
            self.target = nil
            if hits < mission.targetCount { run(.sequence([.wait(forDuration: 0.3), .run { [weak self] in self?.spawnTarget() }])) }
        }
    }

    private func spawnTarget() {
        let node = SKLabelNode(text: targetSymbol)
        node.name = "target"
        node.fontSize = 86
        node.verticalAlignmentMode = .center
        node.horizontalAlignmentMode = .center
        node.position = CGPoint(
            x: CGFloat.random(in: 120...max(121, size.width - 120)),
            y: CGFloat.random(in: 110...max(111, size.height - 100))
        )
        node.setScale(0.2)
        addChild(node)
        node.run(.scale(to: 1, duration: 0.2))
        node.run(.repeatForever(.sequence([.rotate(byAngle: 0.09, duration: 0.5), .rotate(byAngle: -0.09, duration: 0.5)])))
        target = node
    }

    private var targetSymbol: String {
        switch mission.kind {
        case "filterFeed": "✨"
        case "electrosense": "⚡️"
        case "suctionForage": "🦀"
        case "ambushApproach": "◉"
        case "camouflageFind": "🐚"
        case "tailStrike": "🐟"
        case "scentTrack": "〰️"
        case "tidalWalk": "🪨"
        case "jawStrike": "🐠"
        case "energyTrail": "❄️"
        default: "⭐️"
        }
    }
}

