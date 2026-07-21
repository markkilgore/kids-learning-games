import SpriteKit

final class MissionScene: SKScene {
    let mission: MissionDefinition
    var onProgress: ((Int) -> Void)?
    private var hits = 0
    private var target: SKNode?

    init(mission: MissionDefinition, size: CGSize) {
        self.mission = mission
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.01, green: 0.18, blue: 0.32, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        if mission.kind == "ambushApproach" {
            let surface = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height * 0.24))
            surface.fillColor = UIColor(red: 0.78, green: 0.95, blue: 1, alpha: 0.85)
            surface.strokeColor = .clear
            surface.position = CGPoint(x: size.width / 2, y: size.height * 0.88)
            surface.name = "surface"
            addChild(surface)
        }
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
        if mission.kind == "ambushApproach" {
            spawnSilhouette()
            return
        }
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

    private func spawnSilhouette() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -82, y: 0))
        path.addLine(to: CGPoint(x: -42, y: 30))
        path.addCurve(to: CGPoint(x: 56, y: 0), control1: CGPoint(x: -14, y: 58), control2: CGPoint(x: 38, y: 42))
        path.addCurve(to: CGPoint(x: -42, y: -30), control1: CGPoint(x: 38, y: -42), control2: CGPoint(x: -14, y: -58))
        path.closeSubpath()

        let node = SKShapeNode(path: path)
        node.name = "target"
        node.fillColor = UIColor.black.withAlphaComponent(0.8)
        node.strokeColor = UIColor.white.withAlphaComponent(0.4)
        node.lineWidth = 2
        node.position = CGPoint(
            x: CGFloat.random(in: 130...max(131, size.width - 130)),
            y: CGFloat.random(in: size.height * 0.68...max(size.height * 0.69, size.height * 0.82))
        )
        node.zPosition = 2
        node.setScale(0.2)
        addChild(node)
        node.run(.scale(to: 1, duration: 0.2))
        node.run(.repeatForever(.sequence([.moveBy(x: 0, y: 8, duration: 0.7), .moveBy(x: 0, y: -8, duration: 0.7)])))
        target = node
    }

    private var targetSymbol: String {
        switch mission.kind {
        case "filterFeed": "✨"
        case "electrosense": "⚡️"
        case "suctionForage": "🦀"
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
